#!/bin/bash
# Written by xcarrillo@domain.com
# version 1.6
#

DYNASCRIPT="./swiftmq-status.sh"
DYNALOCK="/tmp/status-dynaq.lck"
TEMPFILE="/tmp/dyna.tmp"

if [ -f "$DYNALOCK" ]
then
        echo "WARNING - $DYNALOCK does exist. If you are sure nobody is using $DYNASCRIPT please remove $DYNALOCK"
	exit ${STATE_WARNING}
fi

. /usr/lib/nagios/plugins/utils.sh

# Loop through every argument and assign them correctly
while (( "$#" ))
do
        case $1 in

        -f)
		# Optional. 1 queue name per line in the file. It will do a grep -v for each line in the file. Must be in the same directory as the script
                QUEUES_FILE="$2"
                shift 2
                ;;
        -v)
                # Invert Match, optional. It will do a  grep -v to each line of the file
                IGNORE_FILE="$2"
                shift 2
                ;;
	-p)
		PATTERN="$2"
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


if [[ $QUEUES_FILE != "" ]] && [[ ! -f $QUEUES_FILE ]]; then
	echo "UNKNOWN: QUEUES_FILE must be a valid file"; exit ${STATE_UNKNOWN}
fi
if [[ $IGNORE_FILE != "" ]] && [[ ! -f $IGNORE_FILE ]]; then
	echo "UNKNOWN: IGNORE_FILE must be a valid file"; exit ${STATE_UNKNOWN}
fi
if [[ -z $WARNING ]]; then
        echo "UNKNOWN: WARNING is mandatory"; exit ${STATE_UNKNOWN}
fi
if [[ -z $CRITICAL ]]; then
        echo "UNKNOWN: CRITICAL is mandatory"; exit ${STATE_UNKNOWN}
fi
if test ! -e "$DYNASCRIPT"; then
        echo "CRITICAL - $DYNASCRIPT does not exist"
        exit ${STATE_CRITICAL}
fi

# First we check if this is the active node, if not, we exit with an OK
ARE_WE_ACTIVE=`netstat -na | grep 4001 | grep LISTEN`
EXITSTATUS=$?
if [ $EXITSTATUS -ne 0 ]
then 
	echo "OK: not the active node"
	exit ${STATE_OK}
fi

if [ $QUEUES_FILE ]; then
        $DYNASCRIPT | grep -if $QUEUES_FILE > $TEMPFILE
        # we assume that the given queues don't exist. If they do exist, the next checks will output the correct exit values and messages.
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL: $PATTERN does not exist"
elif [ $IGNORE_FILE ]; then
        $DYNASCRIPT | grep -ivf $IGNORE_FILE > $TEMPFILE
elif [ $PATTERN ]; then
        # If the name of a queue (or queues, you can give "uscc" and it will work for *uscc*) is given, we run the script and grep the pattern
        $DYNASCRIPT | grep -i $PATTERN > $TEMPFILE
else
        $DYNASCRIPT > $TEMPFILE
fi

declare CRITICAL_ARRAY[]
declare WARNING_ARRAY[]
let CRITICAL_INDEX=0
let WARNING_INDEX=0

while read LINE
do
	QUEUE_NAME=`echo $LINE | awk {'print $1'}`
	MESSAGES=`echo $LINE | awk {'print $3'}`

	# We crate 2 arrays that contain 'words' with the names of the queue and their messages. The ++ is so that we can separate them later on.
	# In these arrays we'll have the queues that hit the threshold
	if [[ $MESSAGES -gt $CRITICAL ]]; then
		echo "Matches Critical!"
		CRITICAL_ARRAY[$CRITICAL_INDEX]=$QUEUE_NAME++$MESSAGES 
		let CRITICAL_INDEX++
	elif [[ $MESSAGES -ge $WARNING ]]; then
		echo "Matches Warning!"
                WARNING_ARRAY[$CRITICAL_INDEX]=$QUEUE_NAME++$MESSAGES
                let WARNING_INDEX++
	fi
done < $TEMPFILE

CRITICAL_ARRAY_COUNT=${#CRITICAL_ARRAY[@]}
CRITICAL_ARRAY_CONTENTS=`echo ${CRITICAL_ARRAY[@]} | sed s/"++"/" "/g`
WARNING_ARRAY_COUNT=${#WARNING_ARRAY[@]}
WARNING_ARRAY_CONTENTS=`echo ${WARNING_ARRAY[@]} | sed s/"++"/" "/g`

echo $WARNING_ARRAY_CONTENTS
echo $CRITICAL_ARRAY_CONTENTS
exit

if [[ $WARNING_ARRAY_CONTENTS -gt 0 ]]; then
	echo $WARNING_ARRAY_CONTENTS
elif [[ $CRITICAL_ARRAY_CONTENTS -gt 0 ]]; then
	echo $CRITICAL_ARRAY_CONTENTS
fi

exit 1




MAX_NUMBER=`cat $TEMPFILE | awk {'print $3'} | sort -n -u | tail -1`

if [ ! $MAX_NUMBER ]; then
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL: No queues with pattern $PATTERN found"
else
        MAX_QUEUE=`cat $TEMPFILE | grep $MAX_NUMBER | awk {'print $1'} | tail -1`

        if [[ $MAX_NUMBER -ge $CRITICAL ]]; then
                exitstatus=${STATE_CRITICAL}
                statusmessage="CRITICAL: $MAX_QUEUE has $MAX_NUMBER messages"
        elif [[ $MAX_NUMBER -ge $WARNING ]]; then
                exitstatus=${STATE_WARNING}
                statusmessage="WARNING: $MAX_QUEUE has $MAX_NUMBER messages"
        else
                exitstatus=${STATE_OK}
                statusmessage="OK: no queues have more than $WARNING messages"
        fi
fi

rm -f $TEMPFILE
rm -f $DYNALOCK

echo "$statusmessage"
exit $exitstatus
