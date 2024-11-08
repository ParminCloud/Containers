#!/usr/bin/env bash

LOCKFILE=/opt/parmincloud/backups/backup.lock
exec 100>"$LOCKFILE"

remove-lock() {
	flock -u 100
	flock -xn 100
	rm -f "$LOCKFILE"
}

trap remove-lock EXIT

flock -xn 100 || (
	echo "Backup already running... exiting..."
	exit 1
)

date
