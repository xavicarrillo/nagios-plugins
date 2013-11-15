#!/bin/bash
# Check Interface-Alias plugin for Nagios
# Checks wether there is or not an alias in the network interface list
# Returns OK if there is an alias. CRITICAL otherwise
#
# We could do this via snmp but there is a bug in net-snmp that prevents us to do so:
# https://bugzilla.redhat.com/show_bug.cgi?id=142726
# 
# v 0.1
#

PROGPATH=`echo $0 | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
. $PROGPATH/utils.sh

exitstatus=${STATE_UNKNOWN}
statusmessage="UNKNOWN"

WARNING=$1
CRITICAL=$2

INTERFACE=`/sbin/ifconfig |grep "Link encap"|awk {'print $1'}|grep ":"`
if [ "$INTERFACE " != ' ' ]
then
        exitstatus=${STATE_OK}
        statusmessage="OK - There is an Alias Interface"
else
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL - There is NOT an Alias Interface"
fi

echo "Alias Interface is $statusmessage"
exit $exitstatus

