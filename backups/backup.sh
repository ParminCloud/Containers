#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

LOCKFILE=/opt/parmincloud/backups/backup.lock
exec 100>"$LOCKFILE"

AWS="$(which aws)"

remove-lock() {
	flock -u 100
	flock -xn 100
	rm -f "$LOCKFILE"
}

LOCAL_FILENAME=/tmp/nonexistingfile

cleanup() {
	remove-lock
	rm -f "$LOCAL_FILENAME"
}

trap cleanup EXIT

flock -xn 100 || (
	log "Backup already running... exiting..."
	exit 1
)

log "Stating backup..."

LOCAL_FILENAME=$(/usr/bin/env bash -c "${BACKUP_CMD}")

if [ -n "$BACKUP_PASSWORD" ]; then
	log "Encrypting backup..."
	gpg --symmetric --batch --passphrase "$BACKUP_PASSWORD" "$LOCAL_FILENAME"
	rm -f "$LOCAL_FILENAME"
	LOCAL_FILENAME="$LOCAL_FILENAME.gpg"
fi

log "Uploading backup to S3..."
REMOTE_FILENAME="$(current-datetime).$(extract-filetype "$LOCAL_FILENAME")"

S3_UPLOAD_URI="s3://${S3_BUCKET}/$REMOTE_FILENAME"
if [ -n "$S3_PREFIX" ]; then
	S3_UPLOAD_URI="s3://${S3_BUCKET}/${S3_PREFIX}/$REMOTE_FILENAME"
fi

$AWS s3 cp "$LOCAL_FILENAME" "$S3_UPLOAD_URI"

if [ -n "$BACKUP_RETENTION_DAYS" ]; then
	log "Removing old backups from S3..."
	S3_RETENTION_QUERY="Contents[?LastModified<='$(subtract-date-from-now $BACKUP_RETENTION_DAYS) 00:00:00'].{Key: Key}"
	$AWS s3api list-objects \
		--bucket "${S3_BUCKET}" \
		--prefix "${S3_PREFIX:-}" \
		--query "${S3_RETENTION_QUERY}" \
		--output text | xargs -P "$(nproc)" -I '{}' $AWS s3 rm "s3://${S3_BUCKET}/{}"
fi

log "Backup successfully done"
