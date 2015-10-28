#!/usr/bin/env bash
### INITIALIZE VARIABLES
progname=$(basename "$0")
verbose=0
logfile=""
timeout=10	# default URL timeout
hchck=""
mail=""
logfolder=""
logfile=""

### DEFINE LOGGING AND USAGE FUNCTIONS
prefix_time(){
	cat \
	| while IFS='' read -r line || [[ -n "$line" ]]; do
		timestamp=$(date '+%Y-%m-%d %H:%M:%S')
		echo "$timestamp | $line"
	done \
	| if [ -f "$logfile" ] ; then
		tee -a "$logfile"
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

graburl(){
	grabbed=0
	if [ $grabbed -eq 0 ] ; then
		if [ -n "$(which curl)" ] ;  then
			grabmethod="curl"
			grabbed=1
			curl -s "$1"
		fi
	fi
	if [ $grabbed -eq 0 ] ; then
		if [ -n "$(which wget)" ] ;  then
			grabbed=1
			grabmethod="wget"
			wget -s "$1" -o -
		fi
	fi
}

usage(){
cat <<END
	$progname - crontask (v1.0 - Oct 2015)
	https://github.com/pforret/crontask by Peter Forret
	GNU GENERAL PUBLIC LICENSE (see LICENSE file)
	cron wrapper script, with logging, timeout and heartbeat
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
#set -ex
optionsdone=0
while [ $optionsdone -eq 0 ] ; do
	case "$1" in
		"-v")	
			verbose=1
			log_info "-v: entering verbose mode"
			shift;;
			
		"-h") 
			usage
			break;;
			
		"--hchk")
			hchk="$2"
			log_info "HCHK: http://hchk.io/$hchk"
			shift 2;;
			
		"--mail")
			mail="$2"
			log_info "MAIL: to [$mail]"
			shift 2;;

		"--log")
			logfolder="$2"
			log_info "LOG: in folder [$logfolder]"
			shift 2;;
			
		*)	optionsdone=1
			break;;
	esac
	if [ $# -eq 0 ] ; then
		optionsdone=1
	fi
done
# what is left is the commandline to execute

tasktype="shell"
if [ $(expr $1 : "http://.*") -gt 0 ] ; then
	tasktype="url"
fi
if [ $(expr $1 : "https://.*") -gt -0 ] ; then
	tasktype="url"
fi
if [ "$tasktype" = "url" ] ; then
	# argument is an url
	bname=$(echo "$1" | cut -d/ -f3)	# domain name
	uniq=$(echo "$1" | md5sum | cut -c1-6)
else 
	# argument is a script/executable
	bname=$(basename $1 .sh)
	uniq=$(echo $* | md5sum | cut -c1-6)
fi
day=$(date '+%Y-%m-%d')


## decide on log file
if [ -n "$logfolder" ] ; then
	if [ ! -d "$logfolder" ] ; then
		mkdir "$logfolder"
		sleep 1 # wait until folder is created
	fi
	if [ ! -d "$logfolder" ] ; then
		log_warning "Cannot create log folder [$logfolder]"
	else 
		logname=crontask.$bname.$uniq.$day.log
		logfile=$logfolder/$logname
		if [ ! -f $logfile ] ; then
			echo "### LOG FILE STARTED AT $(date) by $0 ($$)" > $logfile
		fi
		log_info "LOG: file [$logfile]"	
	fi
fi

## decide on tmp file
tmpfolder="/tmp/crontask"
if [ ! -d "$tmpfolder" ] ; then
	mkdir $tmpfolder
	sleep 1
fi
if [ ! -d "$tmpfolder" ] ; then
	log_warning "Cannot create temp folder [$tmpfolder]"
else 
	tmpname=$bname.$uniq.$$.tmp.txt
	tmpfile=$tmpfolder/$tmpname
	log_info "TMP: output file [$tmpfile]"	
fi

#############################################################################
## now run the task
if [ "$tasktype" = "url" ] ; then
	# argument is an url
	log_info "START URL [$1]"
	### DO IT !!!
	graburl "$1" > $tmpfile
	###
	status=$?
else 
	# argument is a script/executable
	log_info "START COMMAND [$*]"
	### DO IT !!!
	($* 2>&1) > $tmpfile
	###
	status=$?
fi
#############################################################################

### now process result
if [ $status -eq 0 ] ; then
	# success
	log_info "TASK WAS OK [$*]"
	if [ -n "$hchk" ] ; then
		log_info "NOW CALLING [http://hchk.io/$hchk]"
		HRESP=$(graburl "http://hchk.io/$hchk")
		if [ "$HRESP" = "OK" ] ; then
			log_info "CALL OK [healthchecks.io]"
		else
			log_warning "COULD NOT REACH [healthchecks.io]"
		fi
	fi
else
	#failure
	log_warning "TASK FAILED [$*]"
fi
log_info "DELETE [$tmpfile]"
rm $tmpfile

