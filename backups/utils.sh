#!/usr/bin/env bash

current-datetime() {
	echo "$(date +"%Y-%m-%dT%H:%M:%S")"
}

log() {
	awk "BEGIN { print \"$@\" > \"/dev/fd/2\" }"
}

extract-filetype() {
	echo "$1" | awk -F. '{
	    if (NF>2) {
		print $(NF-1)"."$NF;
	    } else if (NF==2) {
		print $NF;
	    } else {
		print $0;
	    }
	}'
}

subtract-date-from-now() {
	local DAYS
	local SEC
	DAYS="$1"
	SEC=$((86400 * DAYS))
	date -d "@$(($(date +%s) - SEC))" +"%Y-%m-%d"
}
