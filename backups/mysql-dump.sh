#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

BACKUP_OUT=/tmp/dump.sql.gz
DUMP_MODE=${DUMP_MODE:-mysql}

log "Creating dump of database"
if [ ${DUMP_MODE} == "mariadb" ]; then
	if [ -z "$MARIADB_HOST" ]; then
		log "You need to set the MYSQL_HOST environment variable."
		exit 1
	fi
	if [ -z "$MARIADB_USER" ]; then
		log "You need to set the MYSQL_USER environment variable."
		exit 1
	fi
	if [ -z "$MARIADB_PORT" ]; then
		log "You need to set the MYSQL_PORT environment variable."
		exit 1
	fi
	if [ -z "$MARIADB_PASSWORD" ]; then
		log "You need to set the MYSQL_PASSWORD environment variable."
		exit 1
	fi
	mariadb-dump \
		--host="${MARIADB_HOST}" \
		--port="${MARIADB_PORT}" \
		--password="${MARIADB_PASSWORD}" \
		--user="${MARIADB_USER}" \
		--single-transaction \
		--get-server-public-key \
		--triggers \
		--routines \
		--events \
		--single-transaction \
		--all-databases | gzip -9 >"${BACKUP_OUT}"
else
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
	mysqldump \
		--host="${MYSQL_HOST}" \
		--port="${MYSQL_PORT}" \
		--password="${MYSQL_PASSWORD}" \
		--user="${MYSQL_USER}" \
		--single-transaction \
		--get-server-public-key \
		--triggers \
		--routines \
		--events \
		--single-transaction \
		--all-databases | gzip -9 >"${BACKUP_OUT}"
fi

echo "${BACKUP_OUT}"
