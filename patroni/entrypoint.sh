#!/usr/bin/env bash

set -exu -o pipefail

if [ $1 != "patroni" ]; then
  exec "$@"
fi

echo "Checking if patroni configuration file exists..."
if [ ! -n "${PATRONI_CONFIG}" ]; then
  echo "PATRONI_CONFIG is not set. Exiting."
  exit 1
fi
if [ ! -f "${PATRONI_CONFIG}" ]; then
  echo "Patroni configuration file ${PATRONI_CONFIG} does not exist. Exiting."
  exit 1
fi

echo "Starting Patroni..."
exec patroni \
  "${PATRONI_CONFIG}"
  "$@"
