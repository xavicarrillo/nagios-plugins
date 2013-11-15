#!/bin/bash

JMS1=$1
JMS2=$2
PLUGINSDIR="/usr/lib/nagios/plugins"
. $PLUGINSDIR/utils.sh
EXITSTATUS=${STATE_UNKNOWN} #default
JMS1STATUS=`$PLUGINSDIR/check_nrpe -n -t 20 -H $JMS1 -c check_swiftmq_local_ha.state -a instance1`
JMS2STATUS=`$PLUGINSDIR/check_nrpe -n -t 20 -H $JMS2 -c check_swiftmq_local_ha.state -a instance2`

if [[ "$JMS1STATUS" = "ACTIVE"  && "$JMS2STATUS" = "STANDBY" ]] || [[ "$JMS1STATUS" = "STANDBY" && "$JMS2STATUS" = "ACTIVE" ]]
then
        EXITSTATUS=${STATE_OK}
        STATUSMESSAGE="OK"
else
        EXITSTATUS=${STATE_CRITICAL}
        STATUSMESSAGE="CRITICAL"
fi

echo "$STATUSMESSAGE: $JMS1 status is $JMS1STATUS, $JMS2 status is $JMS2STATUS"
exit $EXITSTATUS

