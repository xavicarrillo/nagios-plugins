#!/bin/bash
# Check Swiftmq Connectivity plugin for Nagios
# Written by Xavier Carrillo <xcarrillo@domain.com>
# Last Modified: 11-Dec-2007
#
# Description:
# This plugin will check if the box running the script can access the active swiftmq server
#
# Example:
# $ check_swiftmq_connectivity.sh nbg2-orangemoc-smq1 nbg2-orangemoc-smq2 4001
#
# v 0.1
#
# ToDo
# Add an usage() function
# Add parameters' checks
#

PLUGINSDIR="/usr/lib/nagios/plugins"
. $PLUGINSDIR/utils.sh
EXITSTATUS=${STATE_UNKNOWN} #default

CHECKTCP=$PLUGINSDIR/check_tcp
SERVER1=$1
SERVER2=$2
PORT=$3


$CHECKTCP -H $SERVER1 -p $PORT -t 2 > /dev/null 
if [ "$?" != 0 ]
then
	# $SERVER1 is not the active one. Is it the second one?
	$CHECKTCP -H $SERVER2 -p $PORT -t 2 > /dev/null
	if [ "$?" = 0 ]
	then
		# $SERVER2 is the active one
		ACTIVE=$SERVER2
	fi
else
	# $SERVER1 is the active one
	ACTIVE=$SERVER1
fi

$CHECKTCP -H $ACTIVE -p $PORT > /dev/null
if [ "$?" = 0 ]
then
	EXITSTATUS=${STATE_OK}
        STATUSMESSAGE="OK: JMS server $ACTIVE is available at port $PORT"
else
	EXITSTATUS=${STATE_CRITICAL}
        STATUSMESSAGE="CRITICAL: JMS server $ACTIVE is NOT available at port $PORT"
fi

echo $STATUSMESSAGE
exit $EXITSTATUS

