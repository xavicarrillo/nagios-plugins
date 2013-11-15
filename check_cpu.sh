#!/bin/bash
# Check CPU Usage plugin for Nagios
# Written by Xavier Carrillo xcarrillo@domain.com
# Last Modified: 14-July-2009
#
# v 0.4 - Added compatibility with Solaris 10
#

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/utils.sh

exitstatus=${STATE_UNKNOWN}
statusmessage="UNKNOWN"

WARNING=$1
CRITICAL=$2

if [ $# -lt 2 ]
then
        exitstatus=${STATE_WARNING}
        statusmessage="WARNING"
        echo "CPU $statusmessage - 2 arguments needed, warning and critical (number over 100)"
        exit $exitstatus
fi

if [ $WARNING -gt $CRITICAL ]
then
        exitstatus=${STATE_WARNING}
        statusmessage="WARNING"
	echo "CPU $statusmessage - CRITICAL has to be greater than WARNING"
	exit $exitstatus
fi

if [ `uname` == "SunOS" ]
then
        CPU_USAGE=`vmstat |tail -1|awk {'print $22'} | xargs echo 100- | bc`
else
        # This one is already averaged over 100. Decimals are removed. We check top twice (-n 2) because the first time does not give accurate results.
        CPU_USAGE=`top -n 2 -b | grep Cpu |tail -1 | awk -F%id {'print $1'} |sed s/" "// | awk -F, {'print $4'} | awk -F. {'print $1'} | xargs echo 100- | bc`
fi

if [ $CPU_USAGE -ge $WARNING ]
then
        exitstatus=${STATE_WARNING}
        statusmessage="WARNING"
fi
if [ $CPU_USAGE -gt $CRITICAL ]
then
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL"
fi
if [ $CPU_USAGE -lt $WARNING ]
then
        exitstatus=${STATE_OK}
        statusmessage="OK"
fi

echo "CPU $statusmessage - usage: $CPU_USAGE% | 'usage'=$CPU_USAGE"
exit $exitstatus

