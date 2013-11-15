#!/bin/bash
# Written by Xavier Carrillo <xcarrillo@domain.com>
# Last Modified: 05-Dec-2007
#
# Description:
# This plugin will Check The Increment of the result value of an sql query in a certain period of time (arg6, in seconds)
#
# v 0.1
#
# ToDo
# Add a usage() function
# Add parameters' checks
#
#./check_sqlquery_count.sh shared-db1 orangeproxy orangeproxy orangeproxy_uk "SELECT COUNT(id) FROM Entry;" 120 4 2
# If the increment of values when we run that query on the sql server is less than 4 in 120 seconds, we get a warning. If the increment is less than 2, we get a critical
#

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/utils.sh
 
IP=$1
USERNAME=$2
PASSWORD=$3
DATABASE=$4
QUERY=$5 # the query has to be passed between quotes ("")
WAIT=$6 # number of seconds to wait for evaluating the increment
WARNING=$7
CRITICAL=$8
EXITSTATUS=${STATE_UNKNOWN} #default

RESULT1=`mysql -h $IP -u$USERNAME -p$PASSWORD -D $DATABASE -e "$QUERY"|tail -1`
sleep $WAIT
RESULT2=`mysql -h $IP -u$USERNAME -p$PASSWORD -D $DATABASE -e "$QUERY"|tail -1`
INCREMENT=$(($RESULT2-$RESULT1))
INCREMENT=5

EXITSTATUS=${STATE_OK}
STATUSMESSAGE="OK"

if [ $(($INCREMENT-1)) -lt $WARNING ]
then
	EXITSTATUS=${STATE_WARNING}
	STATUSMESSAGE="WARNING"
fi
if [ $(($INCREMENT-1)) -lt $CRITICAL ]
then
	EXITSTATUS=${STATE_CRITICAL}
	STATUSMESSAGE="CRITICAL"
fi

echo "$STATUSMESSAGE: the increment for \"$QUERY\" is $INCREMENT"
exit $EXITSTATUS

