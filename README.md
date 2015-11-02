# crontask
* Bash/sh script to use in crontab config
* call scripts or URLs, with optional logging and healthchecks.io integration

## Usage
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
