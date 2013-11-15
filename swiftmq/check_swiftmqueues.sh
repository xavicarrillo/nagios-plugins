#!/bin/bash
# Written by xcarrillo@domain.com
# version 1.4
# Changelog: if $DYNALOCK exists the results of $DYNASCRYPT can't be trusted, for it will send an error message. We quit with a warning.
#

DYNASCRIPT="/opt/domain/bin/swiftmq/swiftmq-status.sh"
DYNALOCK="/tmp/status-dynaq.lck"
TEMPFILE="/tmp/dyna.tmp"
WARNING=$1
CRITICAL=$2
PATTERN=$3 # We can use a pattern to check just some queues. For instance, if we use vodafone, we will grep for that and the alarm will only work for that service.

. /usr/lib/nagios/plugins/utils.sh

# First we check if this is the active node, if not, we exit with an OK
ARE_WE_ACTIVE=`netstat -na|grep 4001|grep LISTEN`
EXITSTATUS=$?
if [ $EXITSTATUS -ne 0 ]
then 
	exitstatus=${STATE_OK}
	statusmessage="OK: not the active node"
	echo "Queues is $statusmessage"
	exit $exitstatus
fi
if [ -f "$DYNALOCK" ]
then
        exitstatus=${STATE_WARNING}
        statusmessage="WARNING - $DYNALOCK does exist. If you are sure nobody is using $DYNASCRIPT please remove $DYNALOCK"
	echo "$statusmessage"
	exit $exitstatus
fi

if test ! -e "$DYNASCRIPT"
then
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL - $DYNASCRIPT does not exist"
else
	if [ $PATTERN ]
	then
		# If the name of a queue (or queues, you can say uscc and it will work for uscc*) is given, we run the script and grep for the pattern
		$DYNASCRIPT|grep -i $PATTERN > $TEMPFILE
               	# we assume that the given queue doesn't exist and let nagios send a critical. If it does exist, the correct variables will overwrite these ones
               	exitstatus=${STATE_CRITICAL}
               	statusmessage="CRITICAL: $PATTERN does not exist"
	else
               	$DYNASCRIPT > $TEMPFILE
	fi

	MAX_NUMBER=`cat $TEMPFILE | awk {'print $3'}|sort -n -u|tail -1`
	MAX_QUEUE=`cat $TEMPFILE | grep $MAX_NUMBER | awk {'print $1'} |tail -1`

       	if [[ $MAX_NUMBER -gt $WARNING ]] || [[ $MAX_NUMBER -eq $WARNING ]]
	then
       	 	exitstatus=${STATE_WARNING}
        	statusmessage="WARNING: $MAX_QUEUE has $MAX_NUMBER messages"
	fi
       	if [[ $MAX_NUMBER -gt $CRITICAL ]] || [[ $MAX_NUMBER -eq $CRITICAL ]]
	then
       		exitstatus=${STATE_CRITICAL}
	        statusmessage="CRITICAL: $MAX_QUEUE has $MAX_NUMBER messages"
	fi
	if [ $MAX_NUMBER -lt $WARNING ]
	then
       		exitstatus=${STATE_OK}
		if [ $PATTERN ]
	        then
	                statusmessage="$PATTERN OK: $MAX_NUMBER messages"
		else
		        statusmessage="OK: no queues with more than $WARNING messages"
		fi
	fi
fi

rm -f $TEMPFILE

echo "$statusmessage"
exit $exitstatus
