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

DATA_DIR=$(mktemp -d)

log "Create basebackup"
pg_basebackup -D ${DATA_DIR} \
	-c fast \
	-X stream \
	-l backup_label \
	-h "$PGHOST" \
	-p "$PGPORT" \
	-U "$PGUSER"


echo "# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
# IPv6 local connections:
host    all             all             ::1/128                 trust
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust

host all,replication all all scram-sha-256" > ${DATA_DIR}/pg_hba.conf

echo "listen_addresses = '*'
port = 5432" > ${DATA_DIR}/postgresql.conf

log "Creating GZipped Tar Archive of backup"

BACKUP_OUT=/tmp/backup.tar.gz

tar -C "$DATA_DIR" --acls --xattrs -cpaf "$BACKUP_OUT" .

echo "${BACKUP_OUT}"
