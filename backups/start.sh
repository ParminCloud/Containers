#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

if [ -z "$S3_BUCKET" ]; then
	log "You need to set the S3_BUCKET environment variable."
	exit 1
fi

if [ -z "$BACKUP_SCHEDULE" ]; then
	exec /opt/parmincloud/backups/backup
else
	JOB="${BACKUP_SCHEDULE} root /opt/parmincloud/backups/backup >/proc/1/fd/1 2>/proc/1/fd/2"
	printf '%s\n%s\n' "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin" "${JOB}" | tee /etc/crontab
	exec cron -f -l 2
fi
