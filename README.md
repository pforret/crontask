![bash_unit CI](https://github.com/pforret/crontask/workflows/bash_unit%20CI/badge.svg)
![Shellcheck CI](https://github.com/pforret/crontask/workflows/Shellcheck%20CI/badge.svg)
![GH Language](https://img.shields.io/github/languages/top/pforret/crontask)
![GH stars](https://img.shields.io/github/stars/pforret/crontask)
![GH tag](https://img.shields.io/github/v/tag/pforret/crontask)
![GH License](https://img.shields.io/github/license/pforret/crontask)
[![basher install](https://img.shields.io/badge/basher-install-white?logo=gnu-bash&style=flat)](https://basher.gitparade.com/package/)

# crontask
* Bash script to use in crontab config
* call scripts or URLs, with optional logging
* integration with e.g. healthchecks.io (upon success)
* integration with e.g. zapier.com (alert upon failure)
* output in MRTG format (in/out/server/uptime)

## Usage 
```
Program: crontask.sh 3.0.0 by peter@forret.com
Updated: Feb 18 23:13:34 2021
Description: run tasks/URLs in your cron
Usage: crontask.sh [-h] [-q] [-v] [-f] [-l <log_dir>] [-t <tmp_dir>] [-m <minutes>] [-y <success>] [-n <failure>] [-s <shell>] [-d <dir>] [-i <icount>] [-o <ocount>] <action> <input?>
Flags, options and parameters:
    -h|--help        : [flag] show usage [default: off]
    -q|--quiet       : [flag] no output [default: off]
    -v|--verbose     : [flag] output more [default: off]
    -f|--force       : [flag] do not ask for confirmation (always yes) [default: off]
    -l|--log_dir <?> : [option] use this folder for log files   [default: /Users/pforret/log/crontask]
    -t|--tmp_dir <?> : [option] ise this folder for temp files  [default: /Users/pforret/.tmp]
    -m|--minutes <?> : [option] cache results for [cache] minutes  [default: 5]
    -y|--success <?> : [option] call upon success (e.g. https://hc-ping.com/eb095278-aaa-bbbb-cccc-7b75c171a6aa
    -n|--failure <?> : [option] call upon failure (e.g. https://hooks.zapier.com/hooks/catch/123456789 )
    -s|--shell <?>   : [option] use this specific shell bash/zsh  [default: bash]
    -d|--dir <?>     : [option] first cd to folder (- = derive from 1st command)  [default: -]
    -i|--icount <?>  : [option] what to output as 1st parameter: lines/words/chars/secs/msecs/head/tail  [default: msecs]
    -o|--ocount <?>  : [option] what to output as 2nd parameter: lines/words/chars/secs/msecs/head/tail  [default: lines]
    <action>         : [parameter] what to do: check/cmd/url
    <input>          : [parameter] command to execute/URL to call (optional)
                                  @github.com:pforret/crontask.git                                             
### TIPS & EXAMPLES
* use crontask cmd to run a command from crontab
  crontask cmd "/path/to/calculate_statistics this that"
* use crontask url to call a URL from crontab
  crontask url "https://.../update"
* use crontask check to check if this script is ready to execute and what values the options/flags are
  crontask check
* use crontask env to generate an example .env file
  crontask env > .env
* use crontask update to update to the latest version
  crontask check
* >>> bash script created with pforret/bashew
* >>> for bash development, also check out pforret/setver and pforret/progressbar   
```

## 🚀 Installation

with [basher](https://github.com/basherpm/basher)

	> basher install pforret/crontask

call in crontab as

    > /Users/[user]/.basher/cellar/bin/crontask ...

or with `git`

	> git clone https://github.com/pforret/crontask.git
	> cd crontask
    > ln -s crontask.sh /usr/bin/crontask

call in crontab as

    > /usr/bin/crontask ...

## Output

* [MRTG format](https://blog.forret.com/2015/10/13/extended-mrtg-format/)
* 4 lines
    * icount : e.g. # msecs to execute command
    * ocount : e.g. # lines of output
    * description
    * update time

### Example

```bash
> crontask cmd "ping -c 1 www.google.com"
500
6
«ping -c 1 www.google.com»: msecs lines
2021-02-19 00:28:04

> crontask url "https://blog.example.com/cron.php" 
270
127
«https://blog.example.com/cron.php»: msecs lines
2021-02-19 00:29:51           
```