# crontask
* Bash/sh script to use in crontab config
* call scripts or URLs, with optional logging and healthchecks.io integration

## Usage
#--- crontask.sh - crontask (v1.0 - Oct 2015)
#--- https://github.com/pforret/crontask by Peter Forret
#--- GNU GENERAL PUBLIC LICENSE (see LICENSE file)
#--- cron wrapper script, with logging, timeout and heartbeat
     Usage:
       crontask.sh [-v] [-h] [--hchk <id>] [--mail <email@example.com] script|url
	-v		:	verbose
	--hchk	:	call a healthchecks.io URL after task finished successfully
	--log	:	add log to file (and keep file)
	--tid	: 	set task identifier (otherwise generated automatically - used for logging)
	--mail	:	send mail after task finished successfully (requires python or php on your server)
	script	:	local script (with full path)
	url  	:	httpp or https URL (requires curl, wget, python or php on your server)

     Examples:
       0  4   * * * crontask.sh /path/daily_cleanup.sh
       15 *   * * * crontask.sh http://example.com/process_queue.php
       15 *   * * * crontask.sh --hchk XXX --log /var/log/cron/ http://example.com/process_queue.php

     crontab tips
     * add MAILTO=your@email.com to the beginning of the crontab config
     * create a symbolic link to crontash.sh: "ln -s /the/path/to/crontask.sh /usr/bin/ct"
