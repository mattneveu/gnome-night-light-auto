# gnome-night-light-auto
## Description
Simulating **Redshift**, **f.lux** behavior with **Gnome** Night Light plugin. While leaving the plugin always on, the script intend to manage the color temperature depending on the sunset/sunrise.

## Configuration
Configuration file in `~/.config/gnome-night-light-auto.cfg` :

```ini
# GPS Location
Latitude: 53.2148
Longitude: 5.7339 
# Fade In duration in minutes (from Day temp to Night temp or vice versa)
Fade_in: 30
# Day/Night Color Temperature (Kelvin)
Day_temp: 5000
Night_temp: 2900
```

## Dependencies
Following packages are required to be installed. 

- Debian/Ubuntu : 
`libjson-parse-perl libconfig-simple-perl libdatetime-perl libdatetime-format-strptime-perl libunix-syslog-perl libdata-dump-perl liblwp-protocol-https-perl`
- Fedora/Redhat : 
`perl-JSON-Parse perl-Config-Simple perl-DateTime perl-DateTime-Format-Strptime perl-Unix-Syslog perl-Data-Dump perl-LWP-Protocol-https`
- Archlinux : 
`perl-json-parse perl-lwp-protocol-https perl-config-simple perl-datetime perl-datetime-format-strptime perl-data-dump perl-unix-syslog`

## Installation/Setup
1. Install the files from this repo to your system
- Script `gnome-night-light-auto.pl` to `/usr/local/bin/gnome-night-light-auto.pl` (with `chmod 0755`)
- File `gnome-night-light-auto.desktop` to `$HOME/.config/autostart/gnome-night-light-auto.desktop` (for automatic startup)
- Config file `gnome-night-light-auto.cfg` to `$HOME/.config/gnome-night-light-auto.cfg`
2. Configure/customize `$HOME/.config/gnome-night-light-auto.cfg` to your location and preferences
