#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

if [ ! -d "$DATA_DIR" ]; then
	log "$DATA_DIR does not exist or type is not directory"
	exit 1
fi

BACKUP_OUT=/tmp/backup.tar.gz

log "Creating GZipped Tar Archive of backups"
tar -C "$DATA_DIR" --acls --xattrs -cpaf "$BACKUP_OUT" .

echo "${BACKUP_OUT}"
