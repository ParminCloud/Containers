#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

if [ -z "$MYSQL_HOST" ]; then
	log "You need to set the MYSQL_HOST environment variable."
	exit 1
fi
if [ -z "$MYSQL_USER" ]; then
	log "You need to set the MYSQL_USER environment variable."
	exit 1
fi
if [ -z "$MYSQL_PORT" ]; then
	log "You need to set the MYSQL_PORT environment variable."
	exit 1
fi
if [ -z "$MYSQL_PASSWORD" ]; then
	log "You need to set the MYSQL_PASSWORD environment variable."
	exit 1
fi

BACKUP_OUT=/tmp/dump.sql.gz

log "Creating dump of database"
mysqldump \
	--host="${MYSQL_HOST}" \
	--port="${MYSQL_PORT}" \
	--password="${MYSQL_PASSWORD}" \
	--user="${MYSQL_USER}" \
	--single-transaction \
	--get-server-public-key \
	--compress \
	--triggers \
	--routines \
	--events \
	--single-transaction \
	--all-databases | gzip -9 > "${BACKUP_OUT}"

echo "${BACKUP_OUT}"
