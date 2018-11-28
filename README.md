# crontask
* Bash/sh script to use in crontab config
* call scripts or URLs, with optional logging
* integration with healthchecks.io (upon success)
* integration with zapier.com (alert upon failure)
* output in MRTG format (in/out/server/uptime)
* based on bash boilerplate at [https://github.com/pforret/bash-boilerplate](https://github.com/pforret/bash-boilerplate)

## Usage 2.0
	Program: crontask2.sh by peter@forret.com
	Version: v2.0 (L:534-MD:6d4d5c)
	Updated: 2018-11-28 17:40
	Usage: crontask2.sh 
				[-h] [-v] [-q] [-f] 
				[-l <logdir>] [-t <tmpdir>] [-c <cache>] [-i <hchk>] [-z <zpwh>] 
				<icount> <ocount> <type> <command>
	Flags, options and parameters:
	    -h|--help      : [flag] show help/usage info [default: off]
	    -v|--verbose   : [flag] show more output (also 'log' statements) [default: off]
	    -q|--quiet     : [flag] show less output (not even MRTG output) [default: off]
	    -f|--force     : [flag] do not ask for confirmation [default: off]
	    -l|--logdir <val>: [optn] use this as folder for log files  [default: /home/peter/DEVL/github/crontask/log]
	    -t|--tmpdir <val>: [optn] use this as folder for temp files  [default: /tmp/crontask2]
	    -c|--cache <val>: [optn] cache results for [cache] minutes  [default: 5]
	    -i|--hchk <val>: [optn] upon success, call healthchecks.io    (e.g. 0df09a4d-aaaa-aaaa-aaaa-852950e13614)
	    -z|--zpwh <val>: [optn] upon failure, call zapier.com webhook (e.g. 199999/aa8iss )
	    <icount>  : [parameter] what to output as 1st line: lines/words/chars/secs/msecs/head/tail
	    <ocount>  : [parameter] what to output as 2nd line: lines/words/chars/secs/msecs/head/tail
	    <type>    : [parameter] what to do: cmd/url
	    <command> : [parameter] command to execute/URL to call

## Usage 1.0
	crontask.sh - crontask (v1.0 - Oct 2015)
	https://github.com/pforret/crontask by Peter Forret
	GNU GENERAL PUBLIC LICENSE (see LICENSE file)
	cron wrapper script, with logging, timeout and heartbeat
	
	Usage:
		crontask.sh [-v] [-h] [--hchk <id>] [--mail <email@example.com] script|url
	-v		:	verbose
	--hchk	:	call a healthchecks.io URL after task finished successfully
	--log	:	add log to file (and keep file)
	--mail	:	send mail after task finished successfully (requires python or php on your server)
	script	:	local script (with full path)
	url  	:	httpp or https URL (requires curl, wget, python or php on your server)

	Examples:
		0  4   * * * /usr/bin/ct /path/daily_cleanup.sh
		15 *   * * * /usr/bin/ct http://example.com/process_queue.php
		15 *   * * * /usr/bin/ct --hchk XXX --log /var/log/cron/ http://example.com/process_queue.php

	crontab tips
	* add the following lines to the beginning of your crontab config:
     	SHELL=/bin/sh
     	PATH=/sbin:/bin:/usr/sbin:/usr/bin:/opt/sbin:/opt/bin
     	MAILTO=your@email.com

	* create a symbolic link from /usr/bin/ct to crontash.sh
     	sudo ln -s /the/path/to/crontask.sh /usr/bin/ct
