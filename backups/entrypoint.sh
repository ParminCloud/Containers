#!/usr/bin/env bash

set -o pipefail -ue

env >> /etc/environment

exec "$@"
