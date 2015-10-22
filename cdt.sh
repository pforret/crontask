#!/usr/bin/env bash
progname=$(basename "$0")
verbose=0
logfile=""
prefix_time(){
	cat \
	| while IFS='' read -r line || [[ -n "$line" ]]; do
		timestamp=$(date '+%Y-%m-%d %H:%M:%S')
		echo "$timestamp | $line"
	done \
	| if [ -f $logfile ] ; then
		tee $logfile
	else
		cat
	fi
}
log_info(){
	if [ $verbose -gt 0 ] ; then
		echo "INFO: $*" | prefix_time
	fi
}

log_warning(){
	echo "WARNING: $*" | prefix_time
}

log_error(){
	echo "ERROR: $*" | prefix_time
	exit 1
}

usage(){
cat <<END
################################################
##### $progname (Oct 2015)
##### (c) October 2015 - Peter Forret - Brightfish
Usage:
  $progname [options] [host1,host2,host3] [command]
END
	exit
}