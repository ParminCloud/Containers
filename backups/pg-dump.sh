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

DATA_DIR="$(mktemp -d)"

trap "rm -rf $DATA_DIR" EXIT

log "Creating dump of database"
pg_dumpall \
	-h "$PGHOST" \
	-p "$PGPORT" \
	-U "$PGUSER" > "${DATA_DIR}/dump.sql"


log "Creating GZipped Tar Archive of backup"

BACKUP_OUT=/tmp/backup.tar.gz

tar -C "$DATA_DIR" --acls --xattrs -cpaf "$BACKUP_OUT" .

rm -rf "$DATA_DIR"

echo "${BACKUP_OUT}"
