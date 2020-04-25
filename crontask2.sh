#!/usr/bin/env bash

# uncomment next line to have time prefix for every output line
#prefix_fmt='+%H:%M:%S | '
prefix_fmt=""
runasroot=-1
# runasroot = 0 :: don't check anything
# runasroot = 1 :: script MUST run as root
# runasroot = -1 :: script MAY NOT run as root

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'
hash(){
  if [[ -n $(which md5sum) ]] ; then
    # regular linux
    md5sum | cut -c1-6
  else
    # macos
    md5 | cut -c1-6
  fi 
}

# change program version to your own release logic
readonly PROGNAME=$(basename "$0" .sh)
readonly PROGFNAME=$(basename "$0")
readonly PROGDIRREL=$(dirname "$0")
if [[ -z "$PROGDIRREL" ]] ; then
  # script is $PATH somewhere
  PROGFULLPATH=$(which "$0")
  readonly PROGDIR=$(dirname "$PROGFULLPATH")
else
  readonly PROGDIR=$(cd "$PROGDIRREL"; pwd)
fi
PROGFULLPATH="$PROGDIR/$PROGFNAME"
readonly PROGLINES=$(< "$PROGFULLPATH" awk 'END {print NR}')
readonly PROGHASH=$(< "$PROGFULLPATH" hash)
readonly PROGUUID="L:${PROGLINES}-MD:${PROGHASH}"
readonly PROGVERS="v2.1"
readonly PROGAUTH="peter@forret.com"
readonly USERNAME=$(whoami)
readonly TODAY=$(date "+%Y-%m-%d")
readonly PROGIDEN="«${PROGNAME} ${PROGVERS}»"
[[ -z "${TEMP:-}" ]] && TEMP=/tmp

### Change the next lines to reflect which flags/options/parameters you need
### flag:   switch a flag 'on' / no extra parameter / e.g. "-v" for verbose
### flag|<short>|<long>|<description>|<default>
### option: set an option value / 1 extra parameter / e.g. "-l error.log" for logging to file
### option|<short>|<long>|<description>|<default>
### param:  comes after the options
### param|<type>|<long>|<description>
### where <type> = 1 for single parameters or <type> = n for (last) parameter that can be a list

list_options() {
echo -n "
flag|h|help|show help/usage info
flag|v|verbose|show more output (also 'log' statements)
flag|q|quiet|show less output (not even 'out' statements)
flag|f|force|do not ask for confirmation

option|l|logdir|use this as folder for log files|./log
option|t|tmpdir|use this as folder for temp files|$TEMP/$PROGNAME
option|c|cache|cache results for [cache] minutes|5
option|i|hchk|upon success, call healthchecks.io    (e.g. 0df09a4d-aaaa-aaaa-aaaa-852950e13614)|
option|z|zpwh|upon failure, call zapier.com webhook (e.g. 199999/aa8iss )|

param|1|icount|what to output as 1st parameter: lines/words/chars/secs/msecs/head/tail
param|1|ocount|what to output as 2nd parameter: lines/words/chars/secs/msecs/head/tail
param|1|type|what to do: cmd/url
param|1|command|command to execute/URL to call
" | grep -v '^#'
}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################
PROGDATE="??"
os_uname=$(uname -s)
[[ "$os_uname" = "Linux" ]]  && PROGDATE=$(stat -c %y "$0" 2>/dev/null | cut -c1-16) # generic linux
[[ "$os_uname" = "Darwin" ]] && PROGDATE=$(stat -f "%Sm" "$0" 2>/dev/null) # for MacOS

readonly ARGS="$*"
#set -e                                  # Exit immediately on error
verbose=0
quiet=0
piped=0
force=0
help=0
tmpd="$TEMP/$PROGNAME"
logd="./log"

[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
#to enable verbose even for option parsing

[[ -t 1 ]] && piped=0 || piped=1        # detect if out put is piped
[[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported

# Defaults

if [[ $piped -eq 0 ]] ; then
  readonly col_reset="\033[0m"
  readonly col_red="\033[1;31m"
  readonly col_grn="\033[1;32m"
  readonly col_ylw="\033[1;33m"
else
  # no colors for piped content
  readonly col_reset=""
  readonly col_red=""
  readonly col_grn=""
  readonly col_ylw=""
fi

if [[ $unicode -gt 0 ]] ; then
  readonly char_succ="✔"
  readonly char_fail="✖"
  readonly char_alrt="➨"
  readonly char_wait="…"
else
  # no unicode chars if not supported
  readonly char_succ="OK "
  readonly char_fail="!! "
  readonly char_alrt="?? "
  readonly char_wait="..."
fi

readonly nbcols=$(tput cols)
readonly wprogress=$((nbcols - 5))
readonly nbrows=$(tput lines)

tmpfile=""
logfile=""

out() {
  ((quiet)) && return
  local message="$*"
  local prefix=""
  if [[ -n $prefix_fmt ]]; then
    prefix=$(date "$prefix_fmt")
  fi
  printf '%b\n' "$prefix$message";
}
#TIP: use «out» to show any kind of output, except when option --quiet is specified
#TIP:> out "User is [$USERNAME]"

progress() {
  ((quiet)) && return
  local message="$*"
  if ((piped)); then
    printf '%b\n' "$message";
    # \r makes no sense in file or pipe
  else
    printf "... %-${wprogress}b\r" "$message                                             ";
    # next line will overwrite this line
  fi
}
#TIP: use «progress» to show one line of progress that will be overwritten by the next output
#TIP:> progress "Now generating file $nb of $total ..."

trap "die \$PROGIDEN: [\$BASH_COMMAND] failed with error code \$?" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for
# trap 'echo ‘$BASH_COMMAND’ failed with error code $?' ERR
safe_exit() { 
  [[ -n "$tmpfile" ]] && [[ -f "$tmpfile" ]] && rm "$tmpfile"
  trap - INT TERM EXIT
  exit
}

is_set()       { local target=$1 ; [[ $target -gt 0 ]] ; }
is_empty()     { local target=$1 ; [[ -z $target ]] ; }
is_not_empty() { local target=$1;  [[ -n $target ]] ; }
#TIP: use «is_empty» and «is_not_empty» to test for variables
#TIP:> if ! confirm "Delete file"; then ; echo "skip deletion" ;   fi

is_file() { local target=$1; [[ -f $target ]] ; }
is_dir()  { local target=$1; [[ -d $target ]] ; }

die()     { out "${col_red}${char_fail} $PROGIDEN${col_reset}: $*" >&2; safe_exit; }
fail()    { out "${col_red}${char_fail} $PROGIDEN${col_reset}: $*" >&2; safe_exit; }
#TIP: use «die» to show error message and exit program
#TIP:> if [[ ! -f $output ]] ; then ; die "could not create output" ; fi

alert()   { out "${col_red}${char_alrt}${col_reset}: $*" >&2 ; }                       # print error and continue
#TIP: use «alert» to show alert message but continue
#TIP:> if [[ ! -f $output ]] ; then ; alert "could not create output" ; fi

success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
#TIP: use «success» to show success message but continue
#TIP:> if [[ -f $output ]] ; then ; success "output was created!" ; fi

announce()  { out "${col_grn}${char_wait}${col_reset}  $*"; sleep 1 ; }
#TIP: use «announce» to show the start of a task
#TIP:> announce "now generating the reports"

log() { if [[ $verbose -gt 0 ]] ; then
  out "${col_ylw}# $* ${col_reset}"
fi ;   } # for some reason this always fails if I use ((verbose)) && 
#TIP: use «log» to information that will only be visible when -v is specified
#TIP:> log "input file: [$inputname] - [$inputsize] MB"

notify()  { if [[ $? == 0 ]] ; then
        success "$*"
      else 
        alert "$*"
      fi }
    
escape()  { echo "$*" | sed 's/\//\\\//g' ; }
#TIP: use «escape» to extra escape '/' paths in regex
#TIP:> sed 's/$(escape $path)//g'

lcase()   { echo "$*" | awk '{print tolower($0)}' ; }
ucase()   { echo "$*" | awk '{print toupper($0)}' ; }
#TIP: use «lcase» and «ucase» to convert to upper/lower case
#TIP:> param=$(lcase $param)

confirm() { [[ $force -gt 0 ]] && return 0; read -p "$1 [y/N] " -n 1; echo " "; [[ $REPLY =~ ^[Yy]$ ]];}
#TIP: use «confirm» for interactive confirmation before doing something
#TIP:> if ! confirm "Delete file"; then ; echo "skip deletion" ;   fi

os_uname=$(uname -s)
os_bits=$(uname -m)
os_version=$(uname -v)

on_mac()  { [[ "$os_uname" = "Darwin" ]] ;  }
on_linux()  { [[ "$os_uname" = "Linux" ]] ; }

on_32bit()  { [[ "$os_bits"  = "i386" ]] ;  }
on_64bit()  { [[ "$os_bits"  = "x86_64" ]] ;  }
#TIP: use «on_mac»/«on_linux»/'on_32bit'/'on_64bit' to only run things on certain platforms
#TIP:> on_mac && log "Running on MacOS"

usage() {
  out "Program: ${col_grn}$PROGFNAME${col_reset} by ${col_ylw}$PROGAUTH${col_reset}"
  out "Version: ${col_grn}$PROGVERS${col_reset} (${col_ylw}$PROGUUID${col_reset})"
  out "Updated: ${col_grn}$PROGDATE${col_reset}"

  echo -n "Usage: $PROGFNAME"
   list_options \
  | awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-10s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [optn] %s",$2,$3,"val",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secr] %s",$2,$3,"val",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-10s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     } else {
          fulltext = fulltext sprintf("\n    %-10s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

tips(){
  < "$0" grep -v "\$0" \
  | awk "
  /TIP: / {\$1=\"\"; gsub(/«/,\"$col_grn\"); gsub(/»/,\"$col_reset\"); print \"*\" \$0}
  /TIP:> / {\$1=\"\"; print \" $col_ylw\" \$0 \"$col_reset\"}
  "
}

init_options() {
  local init_command
    init_command=$(list_options \
    | awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3"=0; "}
    $1 ~ /flag/   && $5 != "" {print $3"="$5"; "}
    $1 ~ /option/ && $5 == "" {print $3"=\" \"; "}
    $1 ~ /option/ && $5 != "" {print $3"="$5"; "}
    ')
    if [[ -n "$init_command" ]] ; then
        #log "init_options: $(echo "$init_command" | wc -l) options/flags initialised"
        eval "$init_command"
   fi
}

verify_programs(){
  log "Running: on $os_uname ($os_version)"
  listprogs=$(echo $*)
  listhash=$(echo "$*" | hash)
  okfile="$PROGDIR/.$PROGNAME.$listhash.verified"
  if [[ -f "$okfile" ]] ; then
    log "Verify : $listprogs -- cached]"
  else 
    log "Verify : $listprogs"
    okall=1
    for prog in "$@" ; do
      if [[ -z $(which "$prog") ]] ; then
        alert "$PROGIDEN needs [$prog] but this program cannot be found on this $os_uname machine"
        okall=0
      fi
    done
    if [[ $okall -eq 1 ]] ; then
      (
        echo "$PROGNAME: check required programs OK"
        echo "$*"
        date 
      ) > "$okfile"
    fi
  fi
}

folder_prep(){
    if [[ -n "$1" ]] ; then
        local folder="$1"
        local maxdays=365
        if [[ -n "$2" ]] ; then
            maxdays=$2
        fi
        if [ ! -d "$folder" ] ; then
            log "Create folder [$folder]"
            mkdir "$folder"
        else
            log "Cleanup: [$folder] - delete files older than $maxdays day(s)"
            find "$folder" -mtime "+$maxdays" -type f -exec rm {} \;
        fi
  fi
}
#TIP: use «folder_prep» to create a folder if needed and otherwise clean up old files
#TIP:> folder_prep "$logd" 7 # delete all files olders than 7 days

expects_single_params(){
  list_options | grep 'param|1|' > /dev/null
}

expects_multi_param(){
  list_options | grep 'param|n|' > /dev/null
}

parse_options() {
    if [[ $# -eq 0 ]] ; then
       usage >&2 ; safe_exit
    fi

    ## first process all the -x --xxxx flags and options
    #set -x
    while true; do
      # flag <flag> is savec as $flag = 0/1
      # option <option> is saved as $option
      if [[ $# -eq 0 ]] ; then
        ## all parameters processed
        break
      fi
      if [[ ! $1 = -?* ]] ; then
        ## all flags/options processed
        break
      fi
    local save_option
      save_option=$(list_options \
        | awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        ')
        if [[ -n "$save_option" ]] ; then
          if echo "$save_option" | grep shift >> /dev/null ; then
            local save_var=$(echo "$save_option" | cut -d= -f1)
            log "Found  : ${save_var}=$2"
          else
            log "Found  : $save_option"
          fi
          eval "$save_option"
        else
            die "cannot interpret option [$1]"
        fi
        shift
    done

    if [[ $help -gt 0 ]] ; then
      echo "### USAGE"
      usage
      echo ""
      echo "### SCRIPT AUTHORING TIPS"
      tips
      safe_exit
    fi

    ## then run through the given parameters
  if expects_single_params ; then
    #log "Process: single params"
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    nb_singles=$(echo "$single_params" | wc -w)
    log "Expect : $nb_singles single parameter(s): $single_params"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$single_params]"
    
    for param in $single_params ; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]]  && die "need parameter [$param]"
      log "Found  : $param=$1"
      eval "$param=$1"
      shift
    done
  else 
    log "No single params to process"
    single_params=""
    nb_singles=0
  fi

  if expects_multi_param ; then
    #log "Process: multi param"
    nb_multis=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    log "Expect : $nb_multis multi parameter: $multi_param"
    [[ $nb_multis -gt 1 ]]  && die "cannot have >1 'multi' parameter: [$multi_param]"
    [[ $nb_multis -gt 0 ]] && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]] ; then
      log "Found  : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else 
    log "No multi param to process"
    nb_multis=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
    log "all parameters have been processed"
  fi
}

[[ $runasroot == 1  ]] && [[ $UID -ne 0 ]] && die "MUST be root to run this script"
[[ $runasroot == -1 ]] && [[ $UID -eq 0 ]] && die "CANNOT be root to run this script"

################### DO NOT MODIFY ABOVE THIS LINE ###################
#####################################################################

## Put your helper scripts here
run_only_show_errors(){
  tmpfile=$(mktemp)
  if ( $* ) 2>> $tmpfile >> $tmpfile ; then
    #all OK
    rm $tmpfile
    return 0
  else
    alert "[$(echo $*)] gave an error"
    cat $tmpfile
    rm $tmpfile
    return -1
  fi
}

calculate(){
  local param="$1"
  local f_stdout="$2"
  local f_stderr="$3" 
  local f_timing="$4"
  if [[ ! -f "$f_timing" ]] ; then
    die "$f_timing mising"
  fi

  case $param in
    "null" )
      number=0
      ;;

    "lines" )
      number=$(wc -l  "$f_stdout" | awk '{print $1}')
      ;;
    "words" )
      number=$(wc -w  "$f_stdout" | awk '{print $1}')
      ;;
    "chars" )
      number=$(wc -c  "$f_stdout" | awk '{print $1}')
      ;;

    "secs"  )
      number=$(grep real "$f_timing" | awk '{print $2}')
      ;;
    "msecs" )
      number=$(grep real "$f_timing" | awk '{print $2*1000}')
      ;;

    "tail" )
      number=$(tail -1 "$f_stdout" | awk '{print 1*$1}')
      ;;
    "head" )
      number=$(head -1 "$f_stdout" | awk '{print 1*$1}')
      ;;
    "tail2" )
      number=$(tail -1 "$f_stderr" | awk '{print 1*$1}')
      ;;
    "head2" )
      number=$(head -1 "$f_stderr" | awk '{print 1*$1}')
      ;;

    *)  
      die "Unknown output [$param]"
  esac
  # log "calculate: [$param]: $number"
  echo $number
}


## Put your main script here
main() {
  log "Program: $PROGFNAME $PROGVERS ($PROGUUID)"
  log "Updated: $PROGDATE"
  folder_prep "$tmpdir" 1
  cmduniq=$(echo $icount $ocount $type $command | hash)
  cachefile=$tmpdir/$PROGNAME.$cmduniq.cache.txt
  log "Caching: $cachefile":
  folder_prep "$logdir" 7
  logfile=$logdir/$PROGNAME.$TODAY.log
  log "Logging: $logfile"
  echo "$(date '+%H:%M:%S') | [$PROGFNAME] $PROGVERS ($PROGUUID) started" >> $logfile

  verify_programs awk bash curl cut date echo find grep head printf sed stat tail uname time

  timenow=$(date +%s)
  if [[ -f "$cachefile" ]] ; then
    #timecache=$(date -r "$cachefile" +%s)
    #secscache=$(expr $timenow - $timecache)
    #minscache=$(expr $secscache / 60)
    minscache=$(date -r "$cachefile" +%s | awk "{secs = $timenow - \$1 ; printf \"%.0f\", secs / 60 }" )
    if [[ $minscache -le $cache ]] ; then
      log "Caching: cachecd  is $minscache minute(s) old - use cached content"
      ((!$quiet)) && cat $cachefile
      safe_exit
    fi
  fi
  f_stdout=$tmpdir/$PROGNAME.$cmduniq.out.txt
  f_stderr=$tmpdir/$PROGNAME.$cmduniq.err.txt
  f_timing=$tmpdir/$PROGNAME.$cmduniq.tim.txt
  tmpfiles="$f_stdout $f_stderr $f_timing"

  type=$(lcase $type)

  progtime=$(which time) # to avoid using shell built-in time command with less options
  progcurl=$(which curl)

  case $type in
    url ) 
      runcmd1=$progcurl
      runcmd2=-s
      ;;
    exec | cmd ) 
      runcmd1=bash
      runcmd2=-c
      ;;
    * )
      die "Unknown type [$type]"
  esac

  log "Now timing the command [$progtime -p bash -c $runcmd1 $runcmd2 $command 1> $f_stdout 2> $f_stderr > $f_timing]"
  # /usr/bin/time -o-- doesn't work on MacOS
  #  if $progtime -o "$f_timing" -p $runcmd1 $runcmd2 $command 1> "$f_stdout" 2> "$f_stderr" ; then
  if $progtime -p bash -c "$runcmd1 $runcmd2 $command 1> $f_stdout 2> $f_stderr" 2> $f_timing ; then
    # program executed ok
    if [[ -n "$hchk" ]] && [[ ! "$hchk" == " " ]]; then
      # ping hchk.io
      webhook="https://hc-ping.com/$hchk"
      log "program success: calling $webhook"
      if curl -s $webhook > /dev/null ; then
        log "Call to [$webhook]: OK"
      else
        alert "Call to [$webhook]: FAILED"
      fi
    fi
    # now generate output for MRTG
    if [[ $quiet -eq 0 ]] ; then
      (
      calculate $icount "$f_stdout" "$f_stderr" "$f_timing"
      calculate $ocount "$f_stdout" "$f_stderr" "$f_timing"
      echo "«${command}»: $icount $ocount"
      date "+%F %T"
      ) | tee $cachefile
    fi
  else 
    # program failed
    cmderror=$(head -1 $f_timing)
    if [[ -n $zpwh ]] ; then
      # call zapier hook
      webhook="https://hooks.zapier.com/hooks/catch/$zpwh"
      log "program failed: calling [$webhook]"
      if curl -s --data "program=$PROGIDEN&user=$USERNAME@$HOSTNAME&command=$type:$command&error=$cmderror" $webhook > /dev/null ; then
        log "Call to [$webhook]: OK"
      else
        alert "Call to [$webhook]: FAILED"
      fi
    fi
    # now generate output for MRTG
    if [[ $quiet -eq 0 ]] ; then
      calculate $icount "$f_stdout" "$f_stderr" "$f_timing"
      calculate $ocount "$f_stdout" "$f_stderr" "$f_timing"
      echo "«$command»: $icount $ocount [error]"
      echo "ERROR: $cmderror"
    fi
  fi

  log "Cleanup: deleting temp files"
  rm -f "$f_stdout"
  rm -f "$f_stderr"
  rm -f "$f_timing"

}

#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################

log "-------- PREPARE $PROGIDEN" # this will show up even if your main() has errors
init_options
parse_options "$@"
log "-------- STARTING (main) $PROGIDEN" # this will show up even if your main() has errors
main
log "-------- FINISH   (main) $PROGIDEN" # a start needs a finish
safe_exit
