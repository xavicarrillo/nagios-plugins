#!/bin/bash
# Check CPU Usage plugin for Nagios
# Written by Xavier Carrillo xcarrillo@domain.com
# Last Modified: 29-April-2008
#
# v 0.3
#

. /usr/local/nagios/libexec/utils.sh

PROTO=$1 #can be either t (tcp) or u (udp)
TARGET=$2 #Connection that we are looking for
COUNT=$3
NUMBER_OF_CONNECTIONS=`netstat -na$PROTOp|grep $TARGET|grep ESTABLISHED|wc -l`

if [ $NUMBER_OF_CONNECTIONS != $COUNT ]
then
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL"
else
        exitstatus=${STATE_OK}
        statusmessage="OK"
fi

echo "$statusmessage: $NUMBER_OF_CONNECTIONS connections established to $TARGET"
exit $exitstatus

