#!/bin/bash
# Written by Xavier Carrillo xcarrillo@domain.com
# Last Modified: 14-Nov-2008
#
# v 0.1
#

HOST1=$1
HOST2=$2
COMMAND=$3
PLUGINSDIR=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PLUGINSDIR/utils.sh

exitstatus=${STATE_UNKNOWN}
statusmessage="UNKNOWN"

HOST1_REQUEST=`$PLUGINSDIR/../check_nrpe -H $HOST1 -c $COMMAND -n`
HOST1_STATUS=$?
HOST2_REQUEST=`$PLUGINSDIR/../check_nrpe -H $HOST2 -c $COMMAND -n`
HOST2_STATUS=$?

if [[ $HOST1_STATUS -eq 0 ]]
then
        exitstatus=${STATE_OK}
        statusmessage=$HOST1_REQUEST
elif [[ $HOST2_STATUS -eq 0 ]]
then
        exitstatus=${STATE_OK}
        statusmessage=$HOST2_REQUEST
else
        # If none of them is OK, we show the lowest alarm (warning=1, critical=2)
        if [[ $HOST1_STATUS -lt $HOST2_STATUS ]]
        then
                exitstatus=$HOST1_STATUS
                statusmessage=$HOST1_REQUEST
        else
                exitstatus=$HOST2_STATUS
                statusmessage=$HOST2_REQUEST
        fi
fi

echo "$statusmessage"
exit $exitstatus

