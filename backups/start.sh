#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

if [ -z "$S3_BUCKET" ]; then
	log "You need to set the S3_BUCKET environment variable."
	exit 1
fi

echo "${BACKUP_SCHEDULE} root /opt/parmincloud/backups/backup >/proc/1/fd/1 2>/proc/1/fd/2" | tee /etc/crontab

exec cron -f -l 2
