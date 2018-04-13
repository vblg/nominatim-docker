#!/bin/bash
service postgresql start
/usr/sbin/apache2ctl -D FOREGROUND
psql -U postgres -h 127.0.0.1 -d nominatim -f /app/warmup.sql
