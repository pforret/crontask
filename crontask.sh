#!/usr/bin/env bash
### Created by Peter Forret ( pforret ) on 2021-02-18
### Based on https://github.com/pforret/bashew 1.14.0
script_version="0.0.1" # if there is a VERSION.md in this script's folder, it will take priority for version number
readonly script_author="peter@forret.com"
readonly script_created="2021-02-18"
readonly run_as_root=-1 # run_as_root: 0 = don't check anything / 1 = script MUST run as root / -1 = script MAY NOT run as root

list_options() {
  echo -n "
flag|h|help|show usage
flag|q|quiet|no output
flag|v|verbose|output more
flag|f|force|do not ask for confirmation (always yes)

option|l|log_dir|use this folder for log files |$HOME/log/crontask
option|t|tmp_dir|ise this folder for temp files|$HOME/.tmp
option|m|minutes|cache results for [cache] minutes|5
option|y|success|call upon success (e.g. https://hc-ping.com/eb095278-aaa-bbbb-cccc-7b75c171a6aa|
option|n|failure|call upon failure (e.g. https://hooks.zapier.com/hooks/catch/123456789 )|
option|s|shell|use this specific shell bash/zsh|bash
option|d|dir|first cd to folder (- = derive from 1st command)|-
option|i|icount|what to output as 1st parameter: lines/words/chars/secs/msecs/head/tail|msecs
option|o|ocount|what to output as 2nd parameter: lines/words/chars/secs/msecs/head/tail|lines

param|1|action|what to do: check/cmd/url
param|?|input|command to execute/URL to call
" | grep -v '^#' | grep -v '^\s*$'
}

#####################################################################
## Put your main script here
#####################################################################

main() {
  log_to_file "[$script_basename] $script_version started"

  delete_upon_exit=()
  prog_time=$(which time) # to avoid using shell built-in time command with less options
  debug "time binary = [$prog_time]"
  prog_curl=$(which curl)
  debug "curl binary = [$prog_curl]"

  prep_rc=""
  # shellcheck disable=SC2154
  case $(basename "$shell") in
    bash )  [[ -f $HOME/.bashrc ]] && prep_rc="source $HOME/.bashrc ; " ;;
    zsh )   [[ -f $HOME/.zshrc ]]  && prep_rc="source $HOME/.zshrc ; "   ;;
  esac

  # shellcheck disable=SC2154
  unique="$(echo "$input" "$icount" "$ocount" | hash 10)"
  # shellcheck disable=SC2154
  cache_file="$tmp_dir/$script_prefix.$action.$unique.cache.txt"
  debug "cache file  = [$cache_file]"

  f_stdout="$tmp_dir/$script_prefix.$action.$unique.out.txt"
  f_stderr="$tmp_dir/$script_prefix.$action.$unique.err.txt"
  f_timing="$tmp_dir/$script_prefix.$action.$unique.tim.txt"
  delete_upon_exit=("$f_stdout" "$f_stderr" "$f_timing")

  action=$(lower_case "$action")
  case $action in
  command | cmd | c)
    #TIP: use «$script_prefix cmd» to run a command from crontab
    #TIP:> $script_prefix cmd "/path/to/calculate_statistics this that"
    # shellcheck disable=SC2154
    do_cmd "$input"
    ;;

  url | u)
    #TIP: use «$script_prefix url» to call a URL from crontab
    #TIP:> $script_prefix url "https://.../update"
    # shellcheck disable=SC2154
    do_url "$input"
    ;;

  check | env)
    ## leave this default action, it will make it easier to test your script
    #TIP: use «$script_prefix check» to check if this script is ready to execute and what values the options/flags are
    #TIP:> $script_prefix check
    #TIP: use «$script_prefix env» to generate an example .env file
    #TIP:> $script_prefix env > .env
    check_script_settings
    ;;

  update)
    ## leave this default action, it will make it easier to test your script
    #TIP: use «$script_prefix update» to update to the latest version
    #TIP:> $script_prefix check
    update_script_to_latest
    ;;

  *)
    die "action [$action] not recognized"
    ;;
  esac
  log_to_file "[$script_basename] ended after $SECONDS secs"
  #TIP: >>> bash script created with «pforret/bashew»
  #TIP: >>> for bash development, also check out «pforret/setver» and «pforret/progressbar»
}

#####################################################################
## Put your helper scripts here
#####################################################################

do_cmd() {
  log_to_file "command [$input]"
  first="${input%% *}"
  debug "execute cmd = [$first]"
  # shellcheck disable=SC2154
  cached="$(check_cache "$cache_file" "$minutes")"
  if [[ -n "$cached" ]] ; then
    debug "Result from cache"
    echo "$cached"
    safe_exit
  fi
  prep_folder=""
  if [[ $dir == "-" ]] ; then
    dir=$(dirname "$first")
  fi
  if [[ -n "$dir" ]] && [[ ! "$dir" == "-" ]] ; then
      prep_folder="cd '$dir' && "
  fi

  if [[ "$(basename "$shell")" ==  "$shell" ]] ; then
    shell="$(which "$shell")"
  fi
  debug "Using shell:  [$shell]"
  debug "Executing:    [$prep_rc $prep_folder $input]"
  if $prog_time -p "$shell" -c "$prep_rc $prep_folder $input 1> '$f_stdout' 2> '$f_stderr' " 2> "$f_timing" ; then
    # command succeeded
    # shellcheck disable=SC2154
    call_webhook "$success"
    if [[ $quiet -eq 0 ]] ; then
      (
      calculate "$icount" "$f_stdout" "$f_stderr" "$f_timing"
      calculate "$ocount" "$f_stdout" "$f_stderr" "$f_timing"
      echo "«${input}»: $icount $ocount"
      date "+%F %T"
      ) | tee "$cache_file"
    fi
  else 
    # program failed
    # shellcheck disable=SC2154
    call_webhook "$failure"
    cmd_error=$(head -1 "$f_timing")
    if [[ $quiet -eq 0 ]] ; then
      calculate "$icount" "$f_stdout" "$f_stderr" "$f_timing"
      calculate "$ocount" "$f_stdout" "$f_stderr" "$f_timing"
      echo "«${input}»: $icount $ocount [error]"
      echo "ERROR: $cmd_error"
    fi
  fi

}

do_url() {
  log_to_file "url [$input]"
  first="curl"
  unique="$(echo "$input" "$icount" "$ocount" | hash 10)"
  cache_file=$tmp_dir/$script_prefix.$first.$unique.txt
  cached="$(check_cache "$cache_file" "$minutes")"
  if [[ -n "$cached" ]] ; then
    debug "Result from cache"
    echo "$cached"
    safe_exit
  fi
  command="'$prog_curl' -s '$input'"
  debug "Executing:    [$command]"
  if [[ "$(basename "$shell")" ==  "$shell" ]] ; then
    shell="$(which "$shell")"
  fi
  debug "Using shell:  [$shell]"
  if $prog_time -p "$shell" -c "$command 1> '$f_stdout' 2> '$f_stderr' " 2> "$f_timing" ; then
    # command succeeded
    # shellcheck disable=SC2154
    call_webhook "$success"
    if [[ $quiet -eq 0 ]] ; then
      (
      calculate "$icount" "$f_stdout" "$f_stderr" "$f_timing"
      calculate "$ocount" "$f_stdout" "$f_stderr" "$f_timing"
      echo "«${input}»: $icount $ocount"
      date "+%F %T"
      ) | tee "$cache_file"
    fi
  else
    # program failed
    # shellcheck disable=SC2154
    call_webhook "$failure"
    cmd_error=$(head -1 "$f_timing")
    if [[ $quiet -eq 0 ]] ; then
      calculate "$icount" "$f_stdout" "$f_stderr" "$f_timing"
      calculate "$ocount" "$f_stdout" "$f_stderr" "$f_timing"
      echo "«${input}»: $icount $ocount [error]"
      echo "ERROR: $cmd_error"
    fi
  fi


}

calculate(){
  local param="$1"
  local f_stdout="$2"
  local f_stderr="$3"
  local f_timing="$4"
  [[ ! -f "$f_timing" ]]  && die "$f_timing missing"

  case $param in
    "null" )  echo 0  ;;

    "lines" ) wc -l  "$f_stdout" | awk '{print $1}' ;;
    "words" ) wc -w  "$f_stdout" | awk '{print $1}' ;;
    "chars" ) wc -c  "$f_stdout" | awk '{print $1}' ;;

    "secs"  ) grep real "$f_timing" | awk '{print $2}'  ;;
    "msecs" ) grep real "$f_timing" | awk '{print $2*1000}' ;;

    "tail" )  tail -1 "$f_stdout" | awk '{print 1*$1}'  ;;
    "head" )  head -1 "$f_stdout" | awk '{print 1*$1}'  ;;
    "tail2")  tail -1 "$f_stderr" | awk '{print 1*$1}'  ;;
    "head2")  head -1 "$f_stderr" | awk '{print 1*$1}'  ;;

    *)       die "Unknown output [$param]"
  esac
}

check_cache(){
  local cache_file="$1"
  local cache_minutes="${2:-5}"
  # shellcheck disable=SC2155
  time_now="$(date +%s)"
  [[ ! -f "$cache_file" ]] && return 0
  age_minutes=$(date -r "$cache_file" +%s | awk -v now="$time_now" '{secs = now - $1 ; printf "%.0f", secs / 60 }' )
  [[ $age_minutes -gt $cache_minutes ]] && return 0
  cat "$cache_file"
}

call_webhook(){
  [[ -z "$1" ]] && return 0
  [[ ! "$1" == "http"* ]] && return 0
  if curl -s "$1" > /dev/null ; then
    debug "Call to [$1]: OK"
  else
    debug "Call to [$1]: FAILED"
  fi
}
#####################################################################
################### DO NOT MODIFY BELOW THIS LINE ###################
#####################################################################

# set strict mode -  via http://redsymbol.net/articles/unofficial-bash-strict-mode/
# removed -e because it made basic [[ testing ]] difficult
set -uo pipefail
IFS=$'\n\t'
# shellcheck disable=SC2120
hash() {
  length=${1:-6}
  # shellcheck disable=SC2230
  if [[ -n $(which md5sum) ]]; then
    # regular linux
    md5sum | cut -c1-"$length"
  else
    # macos
    md5 | cut -c1-"$length"
  fi
}

force=0
help=0
verbose=0
#to enable verbose even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-v" ]] && verbose=1
quiet=0
#to enable quiet even before option parsing
[[ $# -gt 0 ]] && [[ $1 == "-q" ]] && quiet=1

initialise_output() {
  [[ "${BASH_SOURCE[0]:-}" != "${0}" ]] && sourced=1 || sourced=0
  [[ -t 1 ]] && piped=0 || piped=1 # detect if output is piped
  if [[ $piped -eq 0 ]]; then
    col_reset="\033[0m"
    col_red="\033[1;31m"
    col_grn="\033[1;32m"
    col_ylw="\033[1;33m"
  else
    col_reset=""
    col_red=""
    col_grn=""
    col_ylw=""
  fi

  [[ $(echo -e '\xe2\x82\xac') == '€' ]] && unicode=1 || unicode=0 # detect if unicode is supported
  if [[ $unicode -gt 0 ]]; then
    char_succ="✔"
    char_fail="✖"
    char_alrt="➨"
    char_wait="…"
    info_icon="🔎"
    config_icon="🖌️"
    clean_icon="🧹"
    require_icon="📎"
  else
    char_succ="OK "
    char_fail="!! "
    char_alrt="?? "
    char_wait="..."
    info_icon="(i)"
    config_icon="[c]"
    clean_icon="[c]"
    require_icon="[r]"
  fi
  error_prefix="${col_red}>${col_reset}"

  readonly nbcols=$(tput cols 2>/dev/null || echo 80)
  readonly wprogress=$((nbcols - 5))
}

out() { ((quiet)) && true || printf '%b\n' "$*"; }
debug() { if ((verbose)); then out "${col_ylw}# $* ${col_reset}" >&2; else true; fi; }
die() {
  out "${col_red}${char_fail} $script_basename${col_reset}: $*" >&2
  tput bel
  safe_exit
}
alert() { out "${col_red}${char_alrt}${col_reset}: $*" >&2; } # print error and continue
success() { out "${col_grn}${char_succ}${col_reset}  $*"; }
announce() {
  out "${col_grn}${char_wait}${col_reset}  $*"
  sleep 1
}

progress() {
  ((quiet)) || (
    if flag_set ${piped:-0}; then
      out "$*" >&2
    else
      printf "... %-${wprogress}b\r" "$*                                             " >&2
    fi
  )
}

log_to_file() { [[ -n ${log_file:-} ]] && echo "$(date '+%H:%M:%S') | $*" >>"$log_file"; }

lower_case() { echo "$*" | awk '{print tolower($0)}'; }
upper_case() { echo "$*" | awk '{print toupper($0)}'; }

slugify() {
  # shellcheck disable=SC2020
  echo "${1,,}" | xargs | tr 'àáâäæãåāçćčèéêëēėęîïííīįìłñńôöòóœøōõßśšûüùúūÿžźż' 'aaaaaaaaccceeeeeeeiiiiiiilnnoooooooosssuuuuuyzzz' |
    awk '{
    gsub(/https?/,"",$0); gsub(/[\[\]@#$%^&*;,.:()<>!?\/+=_]/," ",$0);
    gsub(/^  */,"",$0); gsub(/  *$/,"",$0); gsub(/  */,"-",$0); gsub(/[^a-z0-9\-]/,"");
    print;
    }' | cut -c1-50
}

confirm() {
  # $1 = question
  flag_set $force && return 0
  read -r -p "$1 [y/N] " -n 1
  echo " "
  [[ $REPLY =~ ^[Yy]$ ]]
}

ask() {
  # $1 = variable name
  # $2 = question
  # $3 = default value
  # not using read -i because that doesn't work on MacOS
  local ANSWER
  read -r -p "$2 ($3) > " ANSWER
  if [[ -z "$ANSWER" ]]; then
    eval "$1=\"$3\""
  else
    eval "$1=\"$ANSWER\""
  fi
}

trap "die \"ERROR \$? after \$SECONDS seconds \n\
\${error_prefix} last command : '\$BASH_COMMAND' \" \
\$(< \$script_install_path awk -v lineno=\$LINENO \
'NR == lineno {print \"\${error_prefix} from line \" lineno \" : \" \$0}')" INT TERM EXIT
# cf https://askubuntu.com/questions/513932/what-is-the-bash-command-variable-good-for

safe_exit() {
  [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]] && rm "$tmp_file"
  if [[ -n "${delete_upon_exit:-}" ]] ; then
    for file in "${delete_upon_exit[@]}" ; do
      [[ -f "$file" ]] && rm "$file"
    done
  fi
  trap - INT TERM EXIT
  debug "$script_basename finished after $SECONDS seconds"
  exit 0
}

flag_set() { [[ "$1" -gt 0 ]]; }

show_usage() {
  out "Program: ${col_grn}$script_basename $script_version${col_reset} by ${col_ylw}$script_author${col_reset}"
  out "Updated: ${col_grn}$script_modified${col_reset}"
  out "Description: run tasks/URLs in your cron"
  echo -n "Usage: $script_basename"
  list_options |
    awk '
  BEGIN { FS="|"; OFS=" "; oneline="" ; fulltext="Flags, options and parameters:"}
  $1 ~ /flag/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [flag] %s [default: off]",$2,$3,$4) ;
    oneline  = oneline " [-" $2 "]"
    }
  $1 ~ /option/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [option] %s",$2,$3 " <?>",$4) ;
    if($5!=""){fulltext = fulltext "  [default: " $5 "]"; }
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /list/  {
    fulltext = fulltext sprintf("\n    -%1s|--%-12s: [list] %s (array)",$2,$3 " <?>",$4) ;
    fulltext = fulltext "  [default empty]";
    oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /secret/  {
    fulltext = fulltext sprintf("\n    -%1s|--%s <%s>: [secret] %s",$2,$3,"?",$4) ;
      oneline  = oneline " [-" $2 " <" $3 ">]"
    }
  $1 ~ /param/ {
    if($2 == "1"){
          fulltext = fulltext sprintf("\n    %-17s: [parameter] %s","<"$3">",$4);
          oneline  = oneline " <" $3 ">"
     }
     if($2 == "?"){
          fulltext = fulltext sprintf("\n    %-17s: [parameter] %s (optional)","<"$3">",$4);
          oneline  = oneline " <" $3 "?>"
     }
     if($2 == "n"){
          fulltext = fulltext sprintf("\n    %-17s: [parameters] %s (1 or more)","<"$3">",$4);
          oneline  = oneline " <" $3 " …>"
     }
    }
    END {print oneline; print fulltext}
  '
}

check_last_version() {
  (
    # shellcheck disable=SC2164
    pushd "$script_install_folder" &>/dev/null
    local remote
    remote="$(git remote -v | grep fetch | awk 'NR == 1 {print $2}')"
    progress "Check for latest version - $remote"
    git remote update &>/dev/null
    if [[ $(git rev-list --count "HEAD...HEAD@{upstream}" 2>/dev/null) -gt 0 ]]; then
      out "There is a more recent update of this script - run <<$script_prefix update>> to update"
    fi
    # shellcheck disable=SC2164
    popd &>/dev/null
  )
}

update_script_to_latest() {
  # run in background to avoid problems with modifying a running interpreted script
  (
    sleep 1
    cd "$script_install_folder" && git pull
  ) &
}

show_tips() {
  ((sourced)) && return 0
  # shellcheck disable=SC2016
  grep <"${BASH_SOURCE[0]}" -v '$0' |
    awk \
      -v green="$col_grn" \
      -v yellow="$col_ylw" \
      -v reset="$col_reset" \
      '
      /TIP: /  {$1=""; gsub(/«/,green); gsub(/»/,reset); print "*" $0}
      /TIP:> / {$1=""; print " " yellow $0 reset}
      ' |
    awk \
      -v script_basename="$script_basename" \
      -v script_prefix="$script_prefix" \
      '{
      gsub(/\$script_basename/,script_basename);
      gsub(/\$script_prefix/,script_prefix);
      print ;
      }'
}

check_script_settings() {
  ## leave this default action, it will make it easier to test your script
  local for_env=0
  local type
  ((piped)) && for_env=1
  [[ "${action:-}" == "env" ]] && for_env=1

  if ((for_env)); then
    debug "Skip dependencies for .env files"
  else
    out "##${col_grn} dependencies${col_reset}: "
    out "$(list_dependencies | cut -d'|' -f1 | sort | xargs)"
    out " "
  fi

  local types=(flag option list param)
  ((for_env)) && types=(flag option list)
  for type in "${types[@]}" ; do
    if [[ -n $(filter_option_type "$type") ]]; then
      out "##${col_grn} $type values ${col_reset}"
      filter_option_type "$type" |
        while read -r name; do
          print_var_value "$type" "$name"
        done
      out " "
    fi
  done
}

filter_option_type() {
  list_options | grep "$1|" | cut -d'|' -f3 | sort | grep -v '^\s*$'
}

print_var_value(){
  key="${2}"
  if [[ "$1" == "list" ]] ; then
    eval "echo \"$key=(\${${key}[@]})\""
  else
    value="${!key}"
    [[ -z "$value" ]] && key="#$key"
    [[ "$value" == *" "* ]] && value="\"$value\""
    echo "$key=$value"
  fi
  }

init_options() {
  local init_command
  init_command=$(list_options |
    grep -v "verbose|" |
    awk '
    BEGIN { FS="|"; OFS=" ";}
    $1 ~ /flag/   && $5 == "" {print $3 "=0; "}
    $1 ~ /flag/   && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /option/ && $5 == "" {print $3 "=\"\"; "}
    $1 ~ /option/ && $5 != "" {print $3 "=\"" $5 "\"; "}
    $1 ~ /list/ {print $3 "=(); "}
    $1 ~ /secret/ {print $3 "=\"\"; "}
    ')
  if [[ -n "$init_command" ]]; then
    eval "$init_command"
  fi
}

expects_single_params() { list_options | grep 'param|1|' >/dev/null; }
expects_optional_params() { list_options | grep 'param|?|' >/dev/null; }
expects_multi_param() { list_options | grep 'param|n|' >/dev/null; }

parse_options() {
  if [[ $# -eq 0 ]]; then
    show_usage >&2
    safe_exit
  fi

  ## first process all the -x --xxxx flags and options
  while true; do
    # flag <flag> is saved as $flag = 0/1
    # option <option> is saved as $option
    if [[ $# -eq 0 ]]; then
      ## all parameters processed
      break
    fi
    if [[ ! $1 == -?* ]]; then
      ## all flags/options processed
      break
    fi
    local save_option
    save_option=$(list_options |
      awk -v opt="$1" '
        BEGIN { FS="|"; OFS=" ";}
        $1 ~ /flag/   &&  "-"$2 == opt {print $3"=1"}
        $1 ~ /flag/   && "--"$3 == opt {print $3"=1"}
        $1 ~ /option/ &&  "-"$2 == opt {print $3"=$2; shift"}
        $1 ~ /option/ && "--"$3 == opt {print $3"=$2; shift"}
        $1 ~ /list/ &&  "-"$2 == opt {print $3"+=($2); shift"}
        $1 ~ /list/ && "--"$3 == opt {print $3"=($2); shift"}
        $1 ~ /secret/ &&  "-"$2 == opt {print $3"=$2; shift #noshow"}
        $1 ~ /secret/ && "--"$3 == opt {print $3"=$2; shift #noshow"}
        ')
    if [[ -n "$save_option" ]]; then
      if echo "$save_option" | grep shift >>/dev/null; then
        local save_var
        save_var=$(echo "$save_option" | cut -d= -f1)
        debug "$config_icon parameter: ${save_var}=$2"
      else
        debug "$config_icon flag: $save_option"
      fi
      eval "$save_option"
    else
      die "cannot interpret option [$1]"
    fi
    shift
  done

  ((help)) && (
    show_usage
    check_last_version
    out "                                  "
    echo "### TIPS & EXAMPLES"
    show_tips

  ) && safe_exit

  ## then run through the given parameters
  if expects_single_params; then
    single_params=$(list_options | grep 'param|1|' | cut -d'|' -f3)
    list_singles=$(echo "$single_params" | xargs)
    single_count=$(echo "$single_params" | count_words)
    debug "$config_icon Expect : $single_count single parameter(s): $list_singles"
    [[ $# -eq 0 ]] && die "need the parameter(s) [$list_singles]"

    for param in $single_params; do
      [[ $# -eq 0 ]] && die "need parameter [$param]"
      [[ -z "$1" ]] && die "need parameter [$param]"
      debug "$config_icon Assign : $param=$1"
      eval "$param=\"$1\""
      shift
    done
  else
    debug "$config_icon No single params to process"
    single_params=""
    single_count=0
  fi

  if expects_optional_params; then
    optional_params=$(list_options | grep 'param|?|' | cut -d'|' -f3)
    optional_count=$(echo "$optional_params" | count_words)
    debug "$config_icon Expect : $optional_count optional parameter(s): $(echo "$optional_params" | xargs)"

    for param in $optional_params; do
      debug "$config_icon Assign : $param=${1:-}"
      eval "$param=\"${1:-}\""
      shift
    done
  else
    debug "$config_icon No optional params to process"
    optional_params=""
    optional_count=0
  fi

  if expects_multi_param; then
    #debug "Process: multi param"
    multi_count=$(list_options | grep -c 'param|n|')
    multi_param=$(list_options | grep 'param|n|' | cut -d'|' -f3)
    debug "$config_icon Expect : $multi_count multi parameter: $multi_param"
    ((multi_count > 1)) && die "cannot have >1 'multi' parameter: [$multi_param]"
    ((multi_count > 0)) && [[ $# -eq 0 ]] && die "need the (multi) parameter [$multi_param]"
    # save the rest of the params in the multi param
    if [[ -n "$*" ]]; then
      debug "$config_icon Assign : $multi_param=$*"
      eval "$multi_param=( $* )"
    fi
  else
    multi_count=0
    multi_param=""
    [[ $# -gt 0 ]] && die "cannot interpret extra parameters"
  fi
}

require_program() {
  require_program="$1"
  path_program=$(which "$require_program" 2>/dev/null)
  [[ -n "$path_program" ]] && debug "️$require_icon required [$require_program] -> [$path_program]"
  [[ -n "$path_program" ]] && return 0
  if [[ $(echo "$required_package" | wc -w) -gt 1 ]]; then
    # example: "setver" "basher install setver"
    install_instructions="$required_package"
  else
    required_package="${2:-}"
    [[ -z "$required_package" ]] && required_package="$require_program"
    if [[ -n "$install_package" ]]; then
      install_instructions="$install_package $required_package"
    else
      install_instructions="(install $required_package with your package manager)"
    fi
  fi
  alert "$script_basename needs [$require_program] but it cannot be found"
  alert "1) install package  : $install_instructions"
  alert "2) add to path      : export PATH=\"[path of your binary]:\$PATH\""
  die "Missing program/script [$require_program]"
}

folder_prep() {
  if [[ -n "$1" ]]; then
    local folder="$1"
    local max_days=${2:-365}
    if [[ ! -d "$folder" ]]; then
      debug "$clean_icon Create folder : [$folder]"
      mkdir -p "$folder"
    else
      debug "$clean_icon Cleanup folder: [$folder] - delete files older than $max_days day(s)"
      find "$folder" -mtime "+$max_days" -type f -exec rm {} \;
    fi
  fi
}

count_words() { wc -w | awk '{ gsub(/ /,""); print}'; }

recursive_readlink() {
  [[ ! -L "$1" ]] && echo "$1" && return 0
  local file_folder
  local link_folder
  local link_name
  file_folder="$(dirname "$1")"
  # resolve relative to absolute path
  [[ "$file_folder" != /* ]] && link_folder="$(cd -P "$file_folder" &>/dev/null && pwd)"
  local symlink
  symlink=$(readlink "$1")
  link_folder=$(dirname "$symlink")
  link_name=$(basename "$symlink")
  [[ -z "$link_folder" ]] && link_folder="$file_folder"
  [[ "$link_folder" == \.* ]] && link_folder="$(cd -P "$file_folder" && cd -P "$link_folder" &>/dev/null && pwd)"
  debug "$info_icon Symbolic ln: $1 -> [$symlink]"
  recursive_readlink "$link_folder/$link_name"
}

lookup_script_data() {
  readonly script_prefix=$(basename "${BASH_SOURCE[0]}" .sh)
  readonly script_basename=$(basename "${BASH_SOURCE[0]}")
  readonly execution_day=$(date "+%Y-%m-%d")
  #readonly execution_year=$(date "+%Y")

  script_install_path="${BASH_SOURCE[0]}"
  debug "$info_icon Script path: $script_install_path"
  script_install_path=$(recursive_readlink "$script_install_path")
  debug "$info_icon Actual path: $script_install_path"
  readonly script_install_folder="$(dirname "$script_install_path")"
  if [[ -f "$script_install_path" ]]; then
    script_hash=$(hash <"$script_install_path" 8)
    script_lines=$(awk <"$script_install_path" 'END {print NR}')
  else
    # can happen when script is sourced by e.g. bash_unit
    script_hash="?"
    script_lines="?"
  fi

  # get shell/operating system/versions
  shell_brand="sh"
  shell_version="?"
  [[ -n "${ZSH_VERSION:-}" ]] && shell_brand="zsh" && shell_version="$ZSH_VERSION"
  [[ -n "${BASH_VERSION:-}" ]] && shell_brand="bash" && shell_version="$BASH_VERSION"
  [[ -n "${FISH_VERSION:-}" ]] && shell_brand="fish" && shell_version="$FISH_VERSION"
  [[ -n "${KSH_VERSION:-}" ]] && shell_brand="ksh" && shell_version="$KSH_VERSION"
  debug "$info_icon Shell type : $shell_brand - version $shell_version"

  readonly os_kernel=$(uname -s)
  os_version=$(uname -r)
  os_machine=$(uname -m)
  install_package=""
  case "$os_kernel" in
  CYGWIN* | MSYS* | MINGW*)
    os_name="Windows"
    ;;
  Darwin)
    os_name=$(sw_vers -productName)       # macOS
    os_version=$(sw_vers -productVersion) # 11.1
    install_package="brew install"
    ;;
  Linux | GNU*)
    if [[ $(which lsb_release) ]]; then
      # 'normal' Linux distributions
      os_name=$(lsb_release -i)    # Ubuntu
      os_version=$(lsb_release -r) # 20.04
    else
      # Synology, QNAP,
      os_name="Linux"
    fi
    [[ -x /bin/apt-cyg ]] && install_package="apt-cyg install"     # Cygwin
    [[ -x /bin/dpkg ]] && install_package="dpkg -i"                # Synology
    [[ -x /opt/bin/ipkg ]] && install_package="ipkg install"       # Synology
    [[ -x /usr/sbin/pkg ]] && install_package="pkg install"        # BSD
    [[ -x /usr/bin/pacman ]] && install_package="pacman -S"        # Arch Linux
    [[ -x /usr/bin/zypper ]] && install_package="zypper install"   # Suse Linux
    [[ -x /usr/bin/emerge ]] && install_package="emerge"           # Gentoo
    [[ -x /usr/bin/yum ]] && install_package="yum install"         # RedHat RHEL/CentOS/Fedora
    [[ -x /usr/bin/apk ]] && install_package="apk add"             # Alpine
    [[ -x /usr/bin/apt-get ]] && install_package="apt-get install" # Debian
    [[ -x /usr/bin/apt ]] && install_package="apt install"         # Ubuntu
    ;;

  esac
  debug "$info_icon System OS  : $os_name ($os_kernel) $os_version on $os_machine"
  debug "$info_icon Package mgt: $install_package"

  # get last modified date of this script
  script_modified="??"
  [[ "$os_kernel" == "Linux" ]] && script_modified=$(stat -c %y "$script_install_path" 2>/dev/null | cut -c1-16) # generic linux
  [[ "$os_kernel" == "Darwin" ]] && script_modified=$(stat -f "%Sm" "$script_install_path" 2>/dev/null)          # for MacOS

  debug "$info_icon Last modif : $script_modified"
  debug "$info_icon Script ID  : $script_lines lines / md5: $script_hash"
  debug "$info_icon Creation   : $script_created"
  debug "$info_icon Running as : $USER@$HOSTNAME"

  # if run inside a git repo, detect for which remote repo it is
  if git status &>/dev/null; then
    readonly git_repo_remote=$(git remote -v | awk '/(fetch)/ {print $2}')
    debug "$info_icon git remote : $git_repo_remote"
    readonly git_repo_root=$(git rev-parse --show-toplevel)
    debug "$info_icon git folder : $git_repo_root"
  else
    readonly git_repo_root=""
    readonly git_repo_remote=""
  fi

  # get script version from VERSION.md file - which is automatically updated by pforret/setver
  [[ -f "$script_install_folder/VERSION.md" ]] && script_version=$(cat "$script_install_folder/VERSION.md")
  # get script version from git tag file - which is automatically updated by pforret/setver
  [[ -n "$git_repo_root" ]] && [[ -n "$(git tag &>/dev/null)" ]] && script_version=$(git tag --sort=version:refname | tail -1)
}

prep_log_and_temp_dir() {
  tmp_file=""
  log_file=""
  if [[ -n "${tmp_dir:-}" ]]; then
    folder_prep "$tmp_dir" 1
    tmp_file=$(mktemp "$tmp_dir/$execution_day.XXXXXX")
    debug "$config_icon tmp_file: $tmp_file"
    # you can use this temporary file in your program
    # it will be deleted automatically if the program ends without problems
  fi
  if [[ -n "${log_dir:-}" ]]; then
    folder_prep "$log_dir" 30
    log_file="$log_dir/$script_prefix.$execution_day.log"
    debug "$config_icon log_file: $log_file"
  fi
}

import_env_if_any() {
  env_files=("$script_install_folder/.env" "$script_install_folder/$script_prefix.env" "./.env" "./$script_prefix.env")

  for env_file in "${env_files[@]}"; do
    if [[ -f "$env_file" ]]; then
      debug "$config_icon Read config from [$env_file]"
      # shellcheck disable=SC1090
      source "$env_file"
    fi
  done
}

[[ $run_as_root == 1 ]] && [[ $UID -ne 0 ]] && die "user is $USER, MUST be root to run [$script_basename]"
[[ $run_as_root == -1 ]] && [[ $UID -eq 0 ]] && die "user is $USER, CANNOT be root to run [$script_basename]"

initialise_output  # output settings
lookup_script_data # find installation folder
init_options       # set default values for flags & options
import_env_if_any  # overwrite with .env if any

if [[ $sourced -eq 0 ]]; then
  parse_options "$@"    # overwrite with specified options if any
  prep_log_and_temp_dir # clean up debug and temp folder
  main                  # run main program
  safe_exit             # exit and clean up
else
  # just disable the trap, don't execute main
  trap - INT TERM EXIT
fi
