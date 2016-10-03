#!/bin/bash

PIDFILE="./watchdog.pid"

if [ -f $PIDFILE ]
then
  PID=$(cat $PIDFILE)
  ps -p $PID > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    echo "Script is already running, killing it"
    kill -9 $PID
    ## create new pidfile anyway as we want the new version running
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      echo "Could not create PID file" >&2
      exit 1
    fi
  else
    ## Process not found assume not running
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
      echo "Could not create PID file" >&2
      exit 1
    fi
  fi
else
  echo $$ > $PIDFILE
  if [ $? -ne 0 ]
  then
    echo "Could not create PID file" >&2
    exit 1
  fi
fi

# while :
# do
#   echo .
#   sleep 1
# done

#set defaults
WATCHDOG_CYCLETIME=30
WATCHDOG_RETRIES=5

#init retry count
read WATCHDOG_RETRIES_CURRENT < watchdog.tries

#HTTP_URL="http://localhost/"

# Parameter parsing
# Source: https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -s|--scriptName)
    PROCESS_SCRIPTNAME="$2"
    shift # past argument
    ;;
    -p|--processEnabled)
    PROCESS_ENABLED=true
    ;;
    -u|--httpURL)
    HTTP_URL="$2"
    shift # past argument
    ;;
    -t|--httpTimeout)
    HTTP_TIMEOUT=$2
    shift # past argument
    ;;
    -h|--httpEnabled)
    HTTP_ENABLED=true
    ;;
    -c|--watchdogCycleTime)
    WATCHDOG_CYCLETIME=$2
    shift # past argument
    ;;
    -r|--watchdogRetries)
    WATCHDOG_RETRIES=$2
    shift # past argument
    ;;
    -b|--watchdogEnableReboot)
    WATCHDOG_REBOOT=true
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done
if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 $1
fi

echo "Path = ${PATH}"
env | grep PATH

echo -e "Watchdog started:\
\nscript name = ${PROCESS_SCRIPTNAME}\
\nprocess monitoring = ${PROCESS_ENABLED}\
\nhttp url = ${HTTP_URL}\
\nhttp timeout = ${HTTP_TIMEOUT}\
\nhttp monitoring = ${HTTP_ENABLED}\
\nwatchdog cycletime = ${WATCHDOG_CYCLETIME}\
\nwatchdog retries = ${WATCHDOG_RETRIES}\
\nwatchdog reboot = ${WATCHDOG_REBOOT}"

function restart_pimatic {
  read WATCHDOG_RETRIES_CURRENT < "watchdog.tries"
  WATCHDOG_RETRIES_CURRENT=$(($WATCHDOG_RETRIES_CURRENT + 1))
  echo $WATCHDOG_RETRIES_CURRENT > "watchdog.tries"
  echo "restarting pimatic... reason = ${1} try = ${WATCHDOG_RETRIES_CURRENT}" >&2
  $PROCESS_SCRIPTNAME restart

}

function check_http {
  # we check if it is hanging by doing an http request 
  # until the timeout is over or we get an connection
  START=`date +%s`
  while [ $(( $(date +%s) - $HTTP_TIMEOUT )) -lt $START ]; do
      curl --insecure --silent "$HTTP_URL" > /dev/null
      HTTP_RESULT=$?
      if [ $HTTP_RESULT -eq 0 ];then
        #if connection successfull we can stop earlier
        break
      fi
      sleep 1
  done
  
  if [ $HTTP_RESULT -ne 0 ];then
    echo "Could not connect via ${HTTP_URL} curl exit code was ${HTTP_RESULT}"
    restart_pimatic "http request failed"
  else
    echo "Webserver at ${HTTP_URL} is alive"
    echo 0 > watchdog.tries
  fi
}

#endlessly loop 
while :
do
  #check if we need to retry again
  if [ $WATCHDOG_RETRIES_CURRENT -gt $WATCHDOG_RETRIES ]; then
    #we have exceeded the retry count
    echo "exceeded retry count, stopping watchdog..." >&2
    #reset the retry count for next startup
    echo 0 > watchdog.tries
    if [ "$WATCHDOG_REBOOT" = true ]; then
      echo "reboot option is active, rebooting..." >&2
      reboot
    fi
    break
  fi

  PROCESS_PID=`ps -ef | grep "bin/node.*${PROCESS_SCRIPTNAME}" | grep -v "grep" | awk '{print $2}'`
  
  if [ -n "${PROCESS_PID}" ] && [ "$PROCESS_ENABLED" = true ]; then
    echo "${PROCESS_SCRIPTNAME} alive with PID ${PROCESS_PID}"
    if [ "$HTTP_ENABLED" = true ]; then
      check_http
    else
      #all selected checks are sucessfull reset retry counter
      echo 0 > watchdog.tries
    fi
  elif [ "$HTTP_ENABLED" = true ]; then
    #this triggers only if process check is not enabled
    #we will only do a check of the webserver
    check_http
  elif [ "$HTTP_ENABLED" != true ] && [ "$PROCESS_ENABLED" != true ]; then
    #all watchdog mechanisms are deactivated
    echo "no watchdog mechanism active, stopping watchdog..." >&2
    break
  else
    echo "${PROCESS_SCRIPTNAME} not running anymore, triggering watchdog"
    restart_pimatic "process disappeared"
  fi



  sleep $WATCHDOG_CYCLETIME
done
