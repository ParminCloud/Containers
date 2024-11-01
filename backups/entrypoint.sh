#!/usr/bin/env bash

env >> /etc/environment

exec "$@"
