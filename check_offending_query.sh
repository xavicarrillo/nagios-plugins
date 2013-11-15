#!/bin/bash

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/utils.sh
USERNAME=$1
PASSWORD=$2
WARNING=$3
CRITICAL=$4

exitstatus=${STATE_UNKNOWN}
statusmessage="UNKNOWN"

#First we check that our username and password are valid:
PROCESSLIST=`mysqladmin -u$USERNAME -p$PASSWORD processlist`
PROCESSLIST_STATUS=$?
if [[ $PROCESSLIST_STATUS != 0 ]]
then
	echo "CRITICAL - Check your Username and Password"
	exit ${STATE_CRITICAL}
fi

offending_seconds=`mysqladmin -u $USERNAME -p$PASSWORD processlist \
		| grep -v 'Binlog Dump' \
		| grep -v 'Waiting for master to send event' \
		| grep -v 'waiting for the slave I/O thread' \
		| awk {'print $12'} \
		| grep -v Time \
		| grep -v '|' \
		| sort -nu \
		| tail -1`

#If there are no queries at all...
if test -e $offending_seconds
then
	offending_minutes=0
else
	offending_minutes=`echo "$offending_seconds/60"|bc`
fi

if [[ $offending_minutes -lt $WARNING ]]
then
        exitstatus=${STATE_OK}
        statusmessage="OK - There are no queries running for more than $WARNING minutes | 'minutes'=$offending_minutes"
fi
if [[ $offending_minutes -gt $WARNING ]] || [[ $offending_minutes -eq $WARNING ]]
then
        exitstatus=${STATE_WARNING}
        statusmessage="WARNING - There is a query that has been running for $offending_minutes minutes | 'minutes'=$offending_minutes"
fi

if [[ $offending_minutes -gt $CRITICAL ]] || [[ $offending_minutes -eq $CRITICAL ]]
then
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL - There is a query that has been running for $offending_minutes minutes | 'minutes'=$offending_minutes"
fi

echo "$statusmessage"
exit $exitstatus

