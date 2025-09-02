#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

if [ -z "$MONGODB_URI" ]; then
	log "You need to set the MONGODB_URI environment variable."
	exit 1
fi

DATA_DIR="$(mktemp -d)"

trap "rm -rf $DATA_DIR" EXIT

log "Creating dump"
mongodump --uri="$MONGODB_URI" -j $(nproc) --out="${DATA_DIR}"

log "Creating GZipped Tar Archive of backup"

BACKUP_OUT=/tmp/backup.tar.gz

tar -C "$DATA_DIR" --acls --xattrs -cpaf "$BACKUP_OUT" .

rm -rf "$DATA_DIR"

echo "${BACKUP_OUT}"
