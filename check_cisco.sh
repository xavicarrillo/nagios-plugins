#!/bin/bash
# Check Cisco Routers via SNMP plugin for Nagios
# Written by Xavier Carrillo xcarrillo@domain.com
# Last Modified: 01-Oct-2008
#
# v 0.1
#

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/utils.sh

exitstatus=${STATE_UNKNOWN}
statusmessage="UNKNOWN"

HOST=$1
CHECK=$2 #check can be 'load', 'mem' or 'temp'
COMMUNITY=$3
WARNING=$4
CRITICAL=$5
SNMPGET=`which snmpget`

if [ "$CHECK" = "mem" ]
then
	MemoryUsed=`$SNMPGET -v 2c -c $COMMUNITY $HOST 1.3.6.1.4.1.9.9.48.1.1.1.5.1 |awk -F: {'print $4'}| tr -d [:blank:]`
	MemoryFree=`$SNMPGET -v 2c -c $COMMUNITY $HOST 1.3.6.1.4.1.9.9.48.1.1.1.6.1 |awk -F: {'print $4'}| tr -d [:blank:]`
	MemoryTotal=`echo $MemoryUsed + $MemoryFree |bc`
	PercentUsed=`echo $MemoryUsed*100/$MemoryTotal|bc`

	if [ $PercentUsed -ge $WARNING ]
	then
	        exitstatus=${STATE_WARNING}
        	statusmessage="Memory is WARNING: $PercentUsed% Memory used"
	elif [ $PercentUsed -ge $CRITICAL ]
	then
	        exitstatus=${STATE_CRITICAL}
        	statusmessage="Memory is CRITICAL: $PercentUsed% Memory used"
	else	
        	exitstatus=${STATE_OK}
	        statusmessage="Memory is OK: $PercentUsed% Memory used"
	fi
fi

if [ "$CHECK" = "load" ]
then
        Load=`$SNMPGET -v 2c -c $COMMUNITY $HOST 1.3.6.1.4.1.9.2.1.58.0  | awk -FINTEGER:  {'print $2'} | tr -d [:blank:]` 

        if [ $Load -ge $WARNING ]
        then
                exitstatus=${STATE_WARNING}
                statusmessage="Load is WARNING: 5 min Load Average is $Load"
        elif [ $Load -ge $CRITICAL ]
        then
                exitstatus=${STATE_CRITICAL}
                statusmessage="Load is CRITICAL: 5 min Load Average is $Load"
        else
                exitstatus=${STATE_OK}
                statusmessage="Load is OK: 5 min Load Average is $Load"
        fi
fi

if [ "$CHECK" = "temp" ]
then
	#	1               normal
	#	2               warning
	#	3               critical
	#	4               shutdown
	#	5               not present

        TemperatureReponse=`$SNMPGET -v 2c -c $COMMUNITY $HOST 1.3.6.1.4.1.9.9.13.1.3.1.6.1  | awk -FINTEGER:  {'print $2'} | tr -d [:blank:]`

	#if $TemperatureReponse is either 3,4 or 5, something's wrong
	# Furthermore, if we don't get any value at all, the output will be a critical
	exitstatus=${STATE_CRITICAL}
	statusmessage="Chassis Temperature is CRITICAL"

        if [ $TemperatureReponse -eq 1 ]
        then
                exitstatus=${STATE_OK}
                statusmessage="Chassis Temperature is OK"
        fi
        if [ $TemperatureReponse -eq 2 ]
        then
                exitstatus=${STATE_WARNING}
                statusmessage="Chassis Temperature is WARNING"
        fi
fi

if [ "$CHECK" = "switchtemp" ]
then
        TemperatureReponse=`$SNMPGET -v 2c -c $COMMUNITY $HOST 1.3.6.1.4.1.9.9.13.1.3.1.3.1005  | awk -F:  {'print $4'} | tr -d [:blank:]`

        if [ $TemperatureReponse -ge $WARNING ]
        then
                exitstatus=${STATE_WARNING}
                statusmessage="Chassis Temperature is WARNING: $TemperatureReponse degrees"
        elif [ $TemperatureReponse -ge $CRITICAL ]
        then
                exitstatus=${STATE_CRITICAL}
                statusmessage="Chassis Temperature is CRITICAL: $TemperatureReponse degrees"
        else 
                exitstatus=${STATE_OK}
                statusmessage="Chassis Temperature is OK: $TemperatureReponse degrees "
        fi
fi

echo "$statusmessage"
exit $exitstatus

