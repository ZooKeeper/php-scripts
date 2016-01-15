#!/bin/bash

CRM_ROOT=/opt/www/html
CRM_PATH=${CRM_ROOT}/html.domain.ru
LOG_ROOT=${CRM_ROOT}/log
LOCK_PATH=/tmp/cron_locks
LOCKS_LOG=${LOG_ROOT}/cron_locks.log
executable=/usr/bin/php
allow_multiple=0
max_execution_time=60
verbose="2>/dev/null"
force=0
log=0

# Function checks if another update process is already running
function check_lock(){
    if [ -f $lock_file ]; then
        # the lock file already exists, so what to do?
        if [[ -f $lock_file && "$(ps -p `/bin/cat $lock_file` | wc -l)" -gt 1 ]]; then
            # process is still running
            timestamp=`date "+%Y-%m-%d-%H:%M:%S"`
            echo "$timestamp Script '$path' with params '$params' already working with pid $lock_file" >> $LOCKS_LOG
            exit 0
        else
            # process not running, but lock file not deleted?
            #echo "$lock_file: orphan lock file warning. Lock file deleted."
            safe_rm_lock
        fi
    fi
}
function safe_rm_lock(){
    if [[ $lock_file && -f $lock_file ]]; then
        /bin/rm $lock_file
    fi
}
function safe_exit(){
    safe_rm_lock
    exit
}

while getopts "s:p:fd:mlv" flag
do
  case $flag in
     p) params=$OPTARG;;
     d) delay=$OPTARG;;
     s) path=$OPTARG;;
     f) force="1";;
     m) allow_multiple=1;;
     v) verbose="";;
     l) log=1;;
  esac
done

if [ ! $path ]; then
    echo "Specify path -s"; exit
fi

full_path=${CRM_PATH}/${path}
log_filename=$(echo $path | sed 's/\//_/g')

# Create lock
if [ ! -d $LOCK_PATH ];then
    echo "Creating ${LOCK_PATH}"
    mkdir $LOCK_PATH
fi

params_serialized=$(echo $params | sed 's/[\/= ]/_/g')
lock_file=${LOCK_PATH}/${log_filename}_${params_serialized}.LOCK
if [ $allow_multiple == 0 ]; then
    check_lock
fi

if [ $log ]; then
    LOG_PATH=${LOG_ROOT}/php_cron_log/${log_filename}_${params_serialized}/`date +'%Y-%m-%d'`
    verbose="2>$LOG_PATH/`date +'%T-%N'`"
  # Create log
  if [ ! -d $LOG_PATH ];then
      echo "Creating ${LOG_PATH}"
      mkdir -p $LOG_PATH
  fi
fi

/bin/echo $$ > $lock_file

if [ ! -f $full_path ];then
    echo "File ${full_path} doesn't exist";exit
fi

if [ $delay ];then
    sleep $delay;
fi

eval "$executable -d max_execution_time=$max_execution_time $full_path force_run=$force $params $verbose 3>&1 1>&2 2>&3 3>&-| sed  \"s%^%$path %g\" | sed 's/^/`date "+%F %T"` /g' >> ${LOG_ROOT}/cron_errors.log"

safe_exit
