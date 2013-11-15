#!/bin/bash
# Check BigIp F5 via SNMP plugin for Nagios
# Written by Xavier Carrillo xcarrillo@domain.com
# Last Modified: 07-Aug-2009
#
# v 0.2
#

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/utils.sh

HOST=$1
CHECK=$2 #check can be 'cpu', 'sync', 'connections'
COMMUNITY=$3
WARNING=$4
CRITICAL=$5
CONNECTIONS_OID=$6
SNMPGET=`which snmpget`
CONCURRENT_CONNECTIONS_BASE_OID=".1.3.6.1.4.1.3375.2.2.10.2.3.1.12"
CONCURRENT_CONNECTIONS_OID="$CONCURRENT_CONNECTIONS_BASE_OID"."$CONNECTIONS_OID"
BYTES_IN_OID="1.3.6.1.4.1.3375.2.1.2.4.4.3.1.3" # Total bytes IN received on the 4 interfaces
BYTES_OUT_OID="1.3.6.1.4.1.3375.2.1.2.4.4.3.1.5" # Total bytes OUT received on the 4 interfaces

function evaluate {

	GET=$1
	CHECK=$2
	WARNING=$3
	CRITICAL=$4

	if [ ! $GET ]
	then
		exitstatus=${STATE_UNKNOWN}
		statusmessage="UNKNOWN"
		echo "$statusmessage"
		exit $exitstatus
	fi

        if [ $GET -ge $WARNING ]
        then
                exitstatus=${STATE_WARNING}
                statusmessage="$CHECK is WARNING: $GET | $CHECK=$GET"
        fi
        if [ $GET -ge $CRITICAL ]
        then
                exitstatus=${STATE_CRITICAL}
                statusmessage="$CHECK is CRITICAL: $GET | $CHECK=$GET"
        fi
        if [ $GET -lt $WARNING ]
        then
                exitstatus=${STATE_OK}
                statusmessage="$CHECK is OK: $GET | $CHECK=$GET"
        fi
}

if [ "$CHECK" = "connections" ]
then
	GET=`$SNMPGET -v 2c -c $COMMUNITY $HOST $CONCURRENT_CONNECTIONS_OID | awk {'print $4'}`
	evaluate $GET $CHECK $WARNING $CRITICAL
fi

if [ "$CHECK" = "load" ]
then
	GET=`$SNMPGET -v 2c -c $COMMUNITY $HOST 1.3.6.1.4.1.2021.10.1.3.2 | awk -FSTRING: {'print $2'} | awk -F. {'print $1'}`
	evaluate $GET $CHECK $WARNING $CRITICAL
fi

if [ "$CHECK" = "sync" ]
then
	GET=`$SNMPGET -v 2c -c $COMMUNITY $HOST 1.3.6.1.4.1.3375.2.1.1.1.1.6.0 |awk -F\" {'print $2'} | awk {'print $1'}`
	# 0 means synced, 1 means out of sync. We only want to send warnings if the F5 are out of sync, but the function evaluate() needs a critical value.
	WARNING=1
	CRITICAL=2 
	evaluate $GET $CHECK $WARNING $CRITICAL
fi

if [ "$CHECK" = "traffic" ]
then
        function walk {
                # Rerturns the total IN bytes (4 interfaces, mgmt not counted)
                snmpwalk -v 2c -c public $HOST $1 | awk {'print $4'} | head -4 | tr -s "\n" "+" | sed s/\+$//
        }

        function TotalBytes() {
                # Adds the Total Bytes IN of the 4 interfaces so that we have the TOTAL traffic
                echo `walk $1` | bc
        }

        BytesInNow=`TotalBytes $BYTES_IN_OID`
        BytesOUTNow=`TotalBytes $BYTES_OUT_OID`
        sleep 59 # Waiting 1 minute to get stats ...
        BytesInLater=`TotalBytes $BYTES_IN_OID`
        BytesOUTLater=`TotalBytes $BYTES_OUT_OID`

        AverageInBytesPerMinute=`echo $BytesInLater-$BytesInNow | bc`
        AverageInKilobytesPerSecond=`echo $AverageInBytesPerMinute/1024/60 | bc`
        AverageOUTBytesPerMinute=`echo $BytesOUTLater-$BytesOUTNow | bc`
        AverageOUTKilobytesPerSecond=`echo $AverageOUTBytesPerMinute/1024/60 | bc`


        WARNIN=`echo $WARNING | awk -F, {'print $1'}`
        WARNOUT=`echo $WARNING | awk -F, {'print $2'}`
        CRITICIN=`echo $CRITICAL | awk -F, {'print $1'}`
        CRITICOUT=`echo $CRITICAL | awk -F, {'print $2'}`

        if [[ $AverageInKilobytesPerSecond -ge $CRITICIN ]] || [[ $AverageOUTKilobytesPerSecond -ge $CRITICOUT ]]
        then
                statusmessage="CRITICAL - IN:$AverageInKilobytesPerSecond KBps, OUT:$AverageOUTKilobytesPerSecond KBps"
                exitstatus=${STATE_CRITICAL}

        elif [[ $AverageInKilobytesPerSecond -ge $WARNIN ]] || [[ $AverageOUTKilobytesPerSecond -ge $WARNOUT ]]
        then
                statusmessage="WARNING - IN:$AverageInKilobytesPerSecond KBps, OUT:$AverageOUTKilobytesPerSecond KBps"
                exitstatus=${STATE_WARNING}
        else
                statusmessage="OK - IN:$AverageInKilobytesPerSecond KBps, OUT:$AverageOUTKilobytesPerSecond KBps"
                exitstatus=${STATE_OK}
        fi

	perfdata="| 'In'=$AverageInKilobytesPerSecond 'Out'=$AverageOUTKilobytesPerSecond"
fi

echo "$statusmessage $perfdata"
exit $exitstatus

