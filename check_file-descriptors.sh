#!/bin/bash
# Check file descriptors
# Written by Eoin Callanan ecallanan@domain.com  
# Last Modified: 19-Jun 2009        
#
# v 0.1
# Script to check number of open files on a process. Optional 4th parameter to search for a particular file descriptor. 
#
PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/utils.sh

exitstatus=${STATE_UNKNOWN}
statusmessage="UNKNOWN"

PROCESS_NAME=$1
WARNING=$2
CRITICAL=$3
FILE_STRING=$4

PID=`ps -ef | grep "${PROCESS_NAME}" | egrep -v "grep|check_" | awk '{print $2}'`

if [ $# -eq 4 ]
then
	NUM_FDs=`sudo -u nbadmin /usr/sbin/lsof -p ${PID} | grep $FILE_STRING | wc -l`
else
	NUM_FDs=`sudo -u nbadmin /usr/sbin/lsof -p ${PID} | wc -l`
fi

if [[ $NUM_FDs -gt $WARNING ]] || [[ $NUM_FDs -eq $WARNING ]]
then
        exitstatus=${STATE_WARNING}
        statusmessage="WARNING"
fi
if [ $NUM_FDs -gt $CRITICAL ]
then
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL"
fi
if [ $NUM_FDs -lt $WARNING ]
then
        exitstatus=${STATE_OK}
        statusmessage="OK"
fi

echo "$statusmessage: File Descriptors with $PROCESS_NAME - number of files : $NUM_FDs"
exit $exitstatus
