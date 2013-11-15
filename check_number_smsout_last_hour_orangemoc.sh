#!/bin/bash

#
# This script gets the number of sms out for the last hour
#
# See "usage" for more details
#
# NOTE: This script expects CRITICAL to always be lower than WARNING
#
#



#-------------
#  VARIABLES
#-------------
SMS_OUT_ID=1
SEND_SMS_SUCCESSFUL_ID=5
PREVIOUS_HOUR=$(date -d "-1hour" +%H)
COUNT=0

#-------------
#  FUNCTIONS
#-------------

usage () {
	echo "UNKNOWN -  Usage: $0 -f (logfile) -w (warning) -c (critical)"
	exit 3
}

exit_unknown () {
	echo "UNKNOWN - $1"
	exit 3
}

#-------------
#    MAIN
#-------------

# Break if there's no arguments
[[ "$#" -eq "0" ]] && usage

# Don't loop more than the number of arguments - see below why this exists
MAX_ARG_LOOPS="$#"

# Get arguments
while (( $# ))
do
	case $1 in

		-f)
			LOGFILE=$2
			shift 2
			;;
		-w)
			WARNING=$2
			shift 2
			;;
		-c)
			CRITICAL=$2
			shift 2
			;;
		*)
			usage
	esac

	# This prevents the while cycle from entering an infinite loop if we don't specify a value for the last argument
	ARG_LOOPS=$((ARG_LOOPS + 1))
	[[ "$ARG_LOOPS" -gt "$MAX_ARG_LOOPS" ]] && break
done


# Validate arguments
if [[ -z $LOGFILE ]]
then
	echo "UNKNOWN: No Logfile defined"
	usage	
elif [[ ! -f $LOGFILE ]]
then
	exit_unknown "Unable to find/read Logfile: $LOGFILE"
elif [[ -z "$WARNING" ]]
then
	exit_unknown "No WARNING value defined"
elif [[ -z "$CRITICAL" ]]
then
	exit_unknown "No CRITICAL value defined"
fi	


# Loop through logfile
while IFS=, read eventLogTime startTime endTime moduleId eventId msisdn result
do
	[[ "$eventId" -eq "$SMS_OUT_ID" && "$result" -eq "$SEND_SMS_SUCCESSFUL_ID"  && "$endTime" =~ "T$PREVIOUS_HOUR" ]] && COUNT=$((COUNT + 1))
done < <(less $LOGFILE)


# Report result
if [[ "$COUNT" -le "$CRITICAL" ]]
then
	echo "CRITICAL: $COUNT OUTGOING SMS in the last hour"
	exit 2
elif [[ "$COUNT" -le "$WARNING" ]]
then
	echo "WARNING: $COUNT OUTGOING SMS in the last hour"
	exit 1
else
	echo "OK: $COUNT OUTGOING SMS in the last hour"
	exit 0
fi
