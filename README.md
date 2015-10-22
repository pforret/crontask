# cron_dothis
* Bash/sh script to use in crontab config
* call scripts or URLs, with optional logging and healthchecks.io integration

## Usage

	cdt.sh [-v] [--hchk <uid>] [--tid <tid>] [--log <folder>] [--mail <user@example.com>] [script|url]

	-v		:	verbose
	--hchk	:	call a healthchecks.io URL after task finished successfully
	--log	:	add log to file (and keep file)
	--tid	: 	set task identifier (otherwise generated automatically - used for logging)
	--mail	:	send mail after task finished successfully (requires python or php on your server)
	script	:	local script (with full path)
	url  	:	httpp or https URL (requires curl, wget, python or php on your server)

## Examples

	0 1  * * *	/path/cdt.sh /run/this/task
	0 1  * * *  /path/cdt.sh "http://www.example.com/"
	0 1  * * *	/path/cdt.sh --hchk [healthchecks.io uid] /run/this/task
	0 1  * * *	/path/cdt.sh --log  [log_dir] "http://www.example.com/"
	0 1  * * *	/path/cdt.sh --mail [me@example.com] "http://www.example.com/"
