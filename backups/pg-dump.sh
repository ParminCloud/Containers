#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

if [ -z "$PGHOST" ]; then
	log "You need to set the PGHOST environment variable."
	exit 1
fi
if [ -z "$PGUSER" ]; then
	log "You need to set the PGUSER environment variable."
	exit 1
fi
if [ -z "$PGPORT" ]; then
	log "You need to set the PGPORT environment variable."
	exit 1
fi
if [ -z "$PGPASSWORD" ]; then
	log "You need to set the PGPASSWORD environment variable."
	exit 1
fi

BACKUP_OUT=/tmp/dump.sql.gz

log "Creating dump of database"
pg_dumpall \
	-h "$PGHOST" \
	-p "$PGPORT" \
	-U "$PGUSER" | gzip -9 > "${BACKUP_OUT}"

echo "${BACKUP_OUT}"
