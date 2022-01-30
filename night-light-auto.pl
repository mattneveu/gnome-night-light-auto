#!/usr/bin/env perl

##########################################################
#
#   Script Name : night-light-auto.pl
#   Description : automatic switching of light temperature
#                  through the seasons
#   Required Args : None
#   Config file: $HOME/.config/night-light-auto.conf
#   Author : Matthieu Neveu (2022-01-28)
#   Version : 0.1
#
##########################################################

use strict;
use warnings;
use JSON::Parse 'parse_json'; # perl-json-parse
use LWP::Simple; # perl-lwp-protocol-https
use Config::Simple; # perl-config-simple
use DateTime; # perl-datetime
use DateTime::Format::Strptime; # perl-datetime-format-strptime
use Data::Dump qw(dump); # perl-data-dump
use Sys::Syslog; # perl-unix-syslog
use Sys::Syslog qw(:standard :macros); 
use constant SUNSET_API => 'https://api.sunrise-sunset.org/json';
use constant CONFIG_FILE_PATH => '/.config/night-light-auto.cfg';
use constant STEP_CONST => 5;

my $cfg = new Config::Simple();
$cfg->read($ENV{"HOME"} . CONFIG_FILE_PATH);
my $fade_color_step = ($cfg->param('Day_temp') - $cfg->param('Night_temp')) / STEP_CONST;
my $fade_time_step = ($cfg->param('Fade_in') / STEP_CONST) * 60;

openlog($_[0], "pid", LOG_DAEMON);
syslog(LOG_INFO, 'Starting daemon');

sub get_sunrise_sunset_data
{
    my ($URL, $jdata);
    $URL = SUNSET_API . "?lat=".$cfg->param('Latitude')."&lng=".$cfg->param('Longitude');
    unless (defined ($jdata = get $URL)) {
        die "could not fetch sunset time from API\n";
    }
    my $pdata = parse_json($jdata);
    my $strp = DateTime::Format::Strptime->new(
        pattern   => '%r'
    );
    my %data = ('updated' => time,
                'sunrise' => $strp->parse_datetime($pdata->{'results'}->{'sunrise'}),
                'sunset' => $strp->parse_datetime($pdata->{'results'}->{'sunset'}),
                'sunrise_fade' => $strp->parse_datetime($pdata->{'results'}->{'sunrise'}),
                'sunset_fade' => $strp->parse_datetime($pdata->{'results'}->{'sunset'}));
    $data{'sunrise_fade'}->subtract('minutes' => $cfg->param('Fade_in'));
    $data{'sunset_fade'}->add('minutes' => $cfg->param('Fade_in'));
    return %data;
}

sub time_to_int
{
    my $dt = $_[0];
    return $dt->strftime("%H%M%S");
}

sub set_gnome_temp_color
{
    # $_[0] == $temp_color (kelvin)
    syslog(LOG_INFO, 'Changing Gnome night light color temp to value: '. $_[0]);
    unless (system("/usr/bin/gsettings", 
                "set", "org.gnome.settings-daemon.plugins.color",
                "night-light-temperature", $_[0])) {
        syslog(LOG_ERR, 'Error while trying to set Gnome night light color temp to new value');
    }
}

sub get_gnome_temp_color
{
    my $gtc = `/usr/bin/gsettings get org.gnome.settings-daemon.plugins.color night-light-temperature`;
    my @gtcv = split(' ', $gtc);
    return $gtcv[1];
}

sub is_full_day
{
    my ($trn, $tsr, $tss) = @_;
    if (time_to_int($trn) >= time_to_int($tsr) && 
        time_to_int($trn) <= time_to_int($tss)) {
        return 1;
    } else {
        return 0;
    }
}

sub is_full_night
{
    my ($trn, $tsr, $tss) = @_;
    if (time_to_int($trn) >= time_to_int($tss)) {
        return 1;
    } else {
        if(time_to_int($trn) <= time_to_int($tsr)) {
            return 1;
        } else {
            return 0;
        }
    }
}

sub is_sun_rising
{
    my ($trn, $tsr, $tsrf) = @_;
    if (time_to_int($trn) >= time_to_int($tsrf) &&
        time_to_int($trn) < time_to_int($tsr)) {
        return 1;
    } else {
        return 0;
    }
}

sub is_sun_setting
{
    my ($trn, $tss, $tssf) = @_;
    if (time_to_int($trn) > time_to_int($tss) &&
        time_to_int($trn) <= time_to_int($tssf)) {
        return 1;
    } else {
        return 0;
    }
}

# Get sun sunrise&sunset from internet API
my %sun_timings = get_sunrise_sunset_data();

# print "Sunrise: ". time_to_int($sun_timings{'sunrise'}) ." \n";
# print "Sunrise_Fadein: ". time_to_int($sun_timings{'sunrise_fade'}) ." \n";
# print "Sunset: ". time_to_int($sun_timings{'sunset'}) ." \n";
# print "Sunset_Fadein: ". time_to_int($sun_timings{'sunset_fade'}) ." \n";

my ($cur_step, $cur_temp);
while (1) 
{
    # check if $sun_timings is not too old (case service rarely restarted)
    if($sun_timings{'updated'} + 3600*24*5 < time)
    {
        %sun_timings = get_sunrise_sunset_data();
    }

    # day or night ?
    if( is_full_day(DateTime->now, 
                    $sun_timings{'sunrise'}, 
                    $sun_timings{'sunset'})) {
        # day                
        if(get_gnome_temp_color() != $cfg->param('Day_temp'))
        {
            set_gnome_temp_color($cfg->param('Day_temp'));
        }
    }
    else
    { 
        # night
        if( is_full_night(DateTime->now,
                        $sun_timings{'sunrise_fade'},
                        $sun_timings{'sunset_fade'})) {
            if(get_gnome_temp_color() != $cfg->param('Night_temp'))
            {
                set_gnome_temp_color($cfg->param('Night_temp'));
            }
        }
        else # in-between - Fade In case
        {   
            $cur_temp = get_gnome_temp_color();
            # Sun rising
            if( is_sun_rising(DateTime->now,
                            $sun_timings{'sunrise'},
                            $sun_timings{'sunrise_fade'})) {
                $cur_step = ($cfg->param('Day_temp') - $cur_temp) / STEP_CONST;
                if($cur_step == 0) {
                    continue; #leaving
                }
                else
                {
                    syslog(LOG_INFO, 'The Sun is rising.');
                    set_gnome_temp_color($cur_temp + $fade_color_step);
                    sleep($fade_time_step);
                }
            }
            else
            {   # sun set
                if( is_sun_setting(DateTime->now,
                                  $sun_timings{'sunset'},
                                  $sun_timings{'sunset_fade'})) {
                    $cur_step = ($cur_temp - $cfg->param('Night_temp')) / STEP_CONST;  
                    if($cur_step == 0) {
                        continue; #leaving
                    }
                    else
                    {
                        syslog(LOG_INFO, 'The Sun is setting.');
                        set_gnome_temp_color($cur_temp - $fade_color_step);
                        sleep($fade_time_step);
                    }               
                }
            }
        }
    }
    # sleep 5m between iterations
    sleep(60*5);
}

closelog();
exit 0;
