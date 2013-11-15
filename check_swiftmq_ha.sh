#!/bin/bash
JMS1=$1
JMS2=$2
JMSDIR=$3
JMS1STATUS=`ssh $JMS1 "tail -1 $JMSDIR/nohup.out"|awk {'print $5'}`
JMS2STATUS=`ssh $JMS2 "tail -1 $JMSDIR/nohup.out"|awk {'print $5'}`
exitstatus=${STATE_UNKNOWN} #default
. /usr/local/nagios/libexec/utils.sh

if [[ "$JMS1STATUS" = "ACTIVE/ACTIVE"  && "$JMS2STATUS" = "STANDBY/STANDBY" ]] || [[ "$JMS1STATUS" = "STANDBY/STANDBY" && "$JMS2STATUS" = "ACTIVE/ACTIVE" ]]
then
        exitstatus=${STATE_OK}
        statusmessage="OK"
else
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL"
fi

echo "$statusmessage: $JMS1 status is $JMS1STATUS, $JMS2 status is $JMS2STATUS"
exit $exitstatus

