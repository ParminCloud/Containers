#!/usr/bin/env bash

## TODO: replace things with actual variables
echo "* * * * * root /opt/parmincloud/backups/backup >/proc/1/fd/1 2>/proc/1/fd/2" | tee /etc/crontab

exec cron -f -l 2
