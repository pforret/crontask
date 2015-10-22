#!/usr/bin/env bash
### INITIALIZE VARIABLES
progname=$(basename "$0")
verbose=0
logfile=""

### DEFINE LOGGING AND USAGE FUNCTIONS
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
#--- $progname - crontask (v1.0 - Oct 2015)
#--- https://github.com/pforret/crontask by Peter Forret
#--- GNU GENERAL PUBLIC LICENSE (see LICENSE file)
#--- cron wrapper script, with logging, timeout and heartbeat
     Usage:
       $progname [-v] [-h] [--hchk <id>] [--mail <email@example.com] script|url

     Examples:
       0  4   * * * $progname /path/daily_cleanup.sh
       15 *   * * * $progname http://example.com/process_queue.php
       15 *   * * * $progname --hchk XXX --log /var/log/cron/ http://example.com/process_queue.php
       
     crontab tips
     * add MAILTO=your@email.com to the beginning of the crontab config
     * create a symbolic link to crontash.sh: "ln -s /the/path/to/crontask.sh /usr/bin/ct"
       then use /usr/bin/ct in your crontab (it's shorter)
END
	exit
}

# exit if there are no arguments
[ $# -eq 0 ] && usage

