#!/usr/bin/env bash

set -o pipefail -ue

. /opt/parmincloud/backups/utils

if [ -z "$SSH_HOST" ]; then
	log "You need to set the SSH_HOST environment variable."
	exit 1
fi
if [ -z "$SSH_PORT" ]; then
	log "You need to set the SSH_PORT environment variable."
	exit 1
fi
if [ -z "$SSH_COMMAND" ]; then
	log "You need to set the SSH_COMMAND environment variable."
	exit 1
fi
export SSH_AUTH="key-file"
if [ ! -f ${HOME}/.ssh/id_rsa ]; then
	export SSH_AUTH="key"
	if [ -z "$SSH_PRIVATE_KEY" ]; then
		export SSH_AUTH="password"
		if [ -z "$SSH_PASSWORD" ]; then
			log "You need to set the SSH_PASSWORD environment variable. or mount private key at /root/.ssh/id_rsa or set SSH_PRIVATE_KEY environment variable"
			exit 1
		fi
	fi
fi

log "Setting up ssh client configuration/agent"
eval $(ssh-agent -s)
if [ "$SSH_AUTH" = "key" ]; then
	echo "${SSH_PRIVATE_KEY}" | tr -d '\r' | ssh-add -
fi
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
ssh-keyscan -p "${SSH_PORT}" "${SSH_HOST}" >> "${HOME}/.ssh/known_hosts"
chmod 644 "${HOME}/.ssh/known_hosts"

BACKUP_OUT=/tmp/backup.gz

log "Creating GZipped file of command output"

if [ "${SSH_AUTH}" = *"key"* ]; then
	ssh -n \
		-p "$SSH_PORT" \
		"$SSH_USER"@"$SSH_HOST" \
		"$REMOTE_COMMAND" | gzip -9 > "${BACKUP_OUT}"
else
	sshpass -p "$SSH_PASSWORD" \
		ssh -n \
		-p "$SSH_PORT" \
		"$SSH_USER"@"$SSH_HOST" \
		"$REMOTE_COMMAND" | gzip -9 > "${BACKUP_OUT}"
fi
echo "${BACKUP_OUT}"
