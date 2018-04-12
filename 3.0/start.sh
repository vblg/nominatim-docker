#!/bin/bash
service postgresql start
/usr/sbin/apache2ctl -D FOREGROUND
psql -U postgres -h $(ip -4 add show eth0|grep inet|awk '{print $2}'|cut -d/ -f1) -d nominatim -f /app/warmup.sql
