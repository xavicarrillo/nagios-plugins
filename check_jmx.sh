#!/bin/bash

#
# This script uses snmp (via sjp) to query the current and max opened files for a JMX enabled java application
#
# Arguments:
#
# -h) hostname to query
# -C) snmp community
# -u) OID that returns current opened files
# -m) OID that returns max opened files
# -w) warning value (in percentage but without % sign) 
# -c) critical value (in percentage but without % sign) 
#
# NOTE: All arguments are MANDATORY
#
# Created by: Bruno Condez
#


# -------------
#   VARIABLES
# -------------

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

PLUGIN_DIR="/usr/lib/nagios/plugins"
CHECK_CMD="$PLUGIN_DIR/check_snmp"


# -------------
#   FUNCTIONS
# -------------

run_query () {

snmpget -v 2c -c $COMMUNITY $HOST $1 | cut -d "=" -f 2 | tr -cd [:digit:] 

}


# -------------
#     MAIN
# -------------

# Loop through every argument and assign them correctly 
while (( "$#" ))
do
	case $1 in

	-h)
		HOST="$2"
		shift 2
		;;
	-C)
		COMMUNITY="$2"
		shift 2
		;;
	-u)
		SNMP_QUERY_USED="$2"
		SNMP_RESULT_USED="$(run_query $SNMP_QUERY_USED)"
		shift 2
		;;
	-m)
		SNMP_QUERY_MAX="$2"
		SNMP_RESULT_MAX="$(run_query $SNMP_QUERY_MAX)"
		shift 2
		;;
	-w)
		WARNING_PERCENTAGE="$2"
		WARNING_DECIMAL=$(echo "$SNMP_RESULT_MAX * 0.${WARNING_PERCENTAGE}" | bc -l | cut -d "." -f1)
		shift 2
		;;
	-c)
		CRITICAL_PERCENTAGE="$2"
		CRITICAL_DECIMAL=$(echo "$SNMP_RESULT_MAX * 0.${CRITICAL_PERCENTAGE}" | bc -l | cut -d "." -f1)
		shift 2
		;;
	esac
done

# Perform some sanity checks
if [[ -z $HOST ]]; then
	echo "UNKNOWN: No hostname found"; exit 3
elif [[ -z $COMMUNITY ]]; then
	echo "UNKNOWN: No community found"; exit 3
elif [[ -z $SNMP_QUERY_USED ]]; then
	echo "UNKNOWN: No snmp oid for currently opened files found"; exit 3
elif [[ -z $SNMP_QUERY_MAX ]]; then
	echo "UNKNOWN: No snmp oid for max opened files found"; exit 3
elif [[ -z $WARNING_PERCENTAGE ]]; then
	echo "UNKNOWN: No warning value found"; exit 3
elif [[ "$WARNING_PERCENTAGE" -lt "1" ]] || [[ "$WARNING_PERCENTAGE" -gt "100" ]]; then
	echo "UNKNOWN: Warning value out of bounds"; exit 3
elif [[ -z $CRITICAL_PERCENTAGE ]]; then
	echo "UNKNOWN: No critical value found"; exit 3
elif [[ "$CRITICAL_PERCENTAGE" -lt "1" ]] || [[ "$CRITICAL_PERCENTAGE" -gt "100" ]]; then
	echo "UNKNOWN: Critical value out of bounds"; exit 3
elif [[ "$SNMP_RESULT_USED" -lt "0" ]] || [[ "$SNMP_RESULT_USED" -gt "65536" ]]; then
	echo "UNKNOWN: Currently Opened Files value \"$SNMP_RESULT_USED\" not recognized"; exit 3
elif [[ "$SNMP_RESULT_MAX" -lt "1" ]] || [[ "$SNMP_RESULT_MAX" -gt "65536" ]]; then
	echo "UNKNOWN: Max Opened Files value \"$SNMP_RESULT_MAX\" not recognized"; exit 3
fi


# Altough we already have the current opened files value (from the query above $SNMP_RESULT_USED - used to perform a simple oid validation), 
# we run the query again using the nagios check since it already contains the necessary logic to determine the state OK/WARNING/CRITICAL.
# Otherwise we would have to implement it here.
$CHECK_CMD -H $HOST -o $SNMP_QUERY_USED -C $COMMUNITY -w $WARNING_DECIMAL -c $CRITICAL_DECIMAL 
