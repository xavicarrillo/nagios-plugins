#!/bin/bash
# Check How Many Messages plugin for Nagios
# Written by Xavier Carrillo <xcarrillo@domain.com>
# Last Modified: 21-Sep-2009
#
# Description:
# This plugin will check the amount of times we got a message in a file between "now" and "X min" ago
# For example, if we see 20 times an "Unable to bind to SMSC" in the last 10 minutes, we have a problem :)
# $ ./check_HowManyMessages3.sh -M INFO -l /opt/domain/app/sng-server/CURRENT/logs/sng-linkbook-server.log -m 10 -c 50 -w 10 -i ignore_LG.txt -d 3600
# CRITICAL: "INFO" detected 18 times within the last 12 minutes | 'times'=18
#
# v 0.7, added support for negative delta times
# v 0.6, added arguments parsing
# v 0.5, improved the way it searches for a string
# v 0.4, added the IGNOREFILE stuff
# v 0.3, added a check to see if there is a date in the begining of the error line
# v 0.2: added the DELTATIME stuff to compensate differences between the log's timezone and the OS timezone.

# ToDo
# Add an usage() function
#

. /usr/lib/nagios/plugins/utils.sh

VERSION=0.7
EXTRA_MINUTE=0

# Loop through every argument and assign them correctly
while (( "$#" ))
do
        case $1 in

        -M)
                MESSAGE="$2"
                shift 2
                ;;
        -l)
                LOGFILE="$2"
                shift 2
                ;;
        -m)
                MINUTES="$2"
                shift 2
                ;;
        -i)
                # We will ignore any message found in this file.
                # Optional
                IGNOREFILE="/usr/lib/nagios/plugins/domain/ignore_files/$2"
                shift 2
                ;;
        -d)
                # Number of seconds to add/substract to the system's date (accepts negative numbers)
                # Mandatory when the log's timezone differs from the system's timezone
                # Otherwise, optional
                #DELTATIME="$2"
		DELTATIME=`echo $2|sed s/minus/-/g` #nrpe doesn't accept negative parameters, so we need to say "-d minus3600" for example.
                shift 2
                ;;

        -w)
                WARNING="$2"
                shift 2
                ;;
        -c)
                CRITICAL="$2"
                shift 2
                ;;
	*)
		echo "UNKNOWN option"
		exit ${STATE_UNKNOWN}
		;;
        esac
done

# Perform some sanity checks

if [[ -z "$MESSAGE" ]]; then
        echo "UNKNOWN: MESSAGE is mandatory"; exit ${STATE_UNKNOWN}
elif [[ -z $LOGFILE ]]; then
        echo "UNKNOWN: LOGFILE is mandatory"; exit ${STATE_UNKNOWN}
elif [[ ! -f $LOGFILE ]]; then
        echo "UNKNOWN: LOGFILE must be a valid file"; exit ${STATE_UNKNOWN}
elif [[ -z $IGNOREFILE ]]; then
        echo "UNKNOWN: IGNOREFILE is mandatory"; exit ${STATE_UNKNOWN}
elif [[ ! -f $IGNOREFILE ]]; then
        echo "UNKNOWN: IGNOREFILE must be a valid file"; exit ${STATE_UNKNOWN}
elif [[ -z $MINUTES ]]; then
        echo "UNKNOWN: MINUTES is mandatory"; exit ${STATE_UNKNOWN}
elif [[ -z $WARNING ]]; then
        echo "UNKNOWN: WARNING is mandatory"; exit ${STATE_UNKNOWN}
elif [[ -z $CRITICAL ]]; then
        echo "UNKNOWN: CRITICAL is mandatory"; exit ${STATE_UNKNOWN}
elif [[ -z $DELTATIME ]]; then
        DELTATIME=0
elif [[ $WARNING -gt $CRITICAL ]]; then
	echo "UNKNOWN: WARNING must be less than CRITICAL"; exit ${STATE_UNKNOWN}
fi

function evaluate
{
	NUMBER_OF_OCCURRENCES=$1
	WARNING=$2
	CRITICAL=$3

	if [[ $NUMBER_OF_OCCURRENCES -ge $CRITICAL ]]; then
		EXITSTATUS=${STATE_CRITICAL}
		STATUSMESSAGE="CRITICAL: \"$MESSAGE\" detected $NUMBER_OF_OCCURRENCES times within the last $REAL_MINUTES minutes | 'times'=$NUMBER_OF_OCCURRENCES" 
	elif [[ $NUMBER_OF_OCCURRENCES -ge $WARNING ]]; then
                EXITSTATUS=${STATE_WARNING}
		STATUSMESSAGE="WARNING: \"$MESSAGE\" detected $NUMBER_OF_OCCURRENCES times within the last $REAL_MINUTES minutes | 'times'=$NUMBER_OF_OCCURRENCES"
	else
		EXITSTATUS=${STATE_OK}
		STATUSMESSAGE="OK: \"$MESSAGE\" detected $NUMBER_OF_OCCURRENCES times within the last $REAL_MINUTES minutes | 'times'=$NUMBER_OF_OCCURRENCES"
	fi
}

########
# MAIN #
########

NOW=`date --date "now" +%s`
PAST0=$NOW+${DELTATIME}
PAST1=$(($PAST0-($MINUTES)*60)) #now-(number of minutes the user gives us in seconds)
PAST2=`date -d @$PAST1 +%Y-%m-%d" "%R` #We put the unix timestamp into the same format as in the logs. Now we have the time "X min ago" in Tomcat format

FIRST_LINE_NUMBER=`grep -an "$PAST2" $LOGFILE | head -1 | awk -F: {'print $1'}` #which is the number of the 1st line begining with that time?
LAST_LINE_NUMBER=`cat $LOGFILE | wc -l` #number of the last line of the logfile
FIRST_LINE_NUMBER_SIZE=`echo $FIRST_LINE_NUMBER | wc -w`

# If $FIRST_LINE_NUMBER is empty, the date we were looking for is not on the logs, because there's not enough traffic and therefore that particular date wasn't write in the logs.
while [[ $FIRST_LINE_NUMBER_SIZE -eq 0 ]] && [[ $EXTRA_MINUTE -lt 10 ]]
do
	# Let's try going back in time, from minute to minute until we find the date on the logs
	# but not more than 30 min or we could fall in an endless loop if we are going back so much that the dates were never logged in this file.

	let EXTRA_MINUTE=$EXTRA_MINUTE+1
	PAST3=$(($PAST1-($EXTRA_MINUTE)*60))
	PAST4=`date -d @$PAST3 +%Y-%m-%d" "%R`
	FIRST_LINE_NUMBER=`grep -an "$PAST4" $LOGFILE | head -1 | awk -F: {'print $1'}` 
	FIRST_LINE_NUMBER_SIZE=`echo $FIRST_LINE_NUMBER | wc -w`
done

let REAL_MINUTES=$MINUTES+$EXTRA_MINUTE

if [[ $FIRST_LINE_NUMBER_SIZE -eq 0 ]] # if this is empty it's because within the last $REAL_MINUTES in the logs, we didn't find the date we are looking for
then
	NUMBER_OF_OCCURRENCES=0
        EXITSTATUS=${STATE_OK}
        STATUSMESSAGE="OK: \"$MESSAGE\" was detected $NUMBER_OF_OCCURRENCES times within the last $REAL_MINUTES minutes | 'times'=$NUMBER_OF_OCCURRENCES"
else
	LINES2SHOW=$(($LAST_LINE_NUMBER-$FIRST_LINE_NUMBER)) # Substracting them we know how many lines we have to show. Those lines are the logged lines for the last X min.
		# Now we count the number ot times the message appears in the logfile, but only for the time threshold we are interested in: now - (X min).
		# We output the last lines of the log (which correspond to the time period we are interested in and grep for the message.
		# Also, we make sure that the line begins with a proper formated date (from 2000-01-01 to 2099-12-31)
		# Or if it starts with com.domain because some relevant expressions get trunkated and don't have a date at the beginning of the line.
	COMMAND="tail -$LINES2SHOW $LOGFILE | egrep -ia '$MESSAGE' | egrep -i '^20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]|^com.domain|^java.util|^java.net'"
	# Same thing with regex: egrep $'[2c][0o][0-9m][0-9.][n-][e[0-1][w[0-9][b-][a[0-3][y[0-9]'" 

	# The ignore file accepts comments, so if the line begins with '#' we don't use that line
        NUMBER_OF_OCCURRENCES=`echo "$COMMAND | grep -vf $IGNOREFILE | grep -v '^#' | wc -l" | sh`

	evaluate $NUMBER_OF_OCCURRENCES $WARNING $CRITICAL

fi

echo $STATUSMESSAGE
exit $EXITSTATUS

