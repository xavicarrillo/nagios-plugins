#!/bin/bash

#
# This script gets the number of registrations for the last X Minutes
#
# Several arguments need to be passed for this script to work
# See "usage" for more details
#
# NOTE: This script expects CRITICAL to always be lower than WARNING
#
#

#--------------
#  FUNCTIONS  
#--------------

usage () {
        echo "UNKNOWN - Usage: $0 -h (db host) -u (db user) -p (db password) -d (database) -m (minutes) -w (warning) -c (critical)"
        exit 3
}



#--------------
#     MAIN   
#--------------

for LOOP in `seq 1 2 $#`
do
	case $1 in

	-h)
		DBHOST=$2
		shift 2
		;;
	-u)
		DBUSER=$2
		shift 2
		;;
	-p)
		DBPASS=$2
		shift 2
		;;
	-d)
		DATABASE=$2
		shift 2
		;;
	-m)
		MINUTES=$2
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
	esac
done



# Validate Arguments
if [ -z $DBHOST ]
then
	usage
elif ! host $DBHOST > /dev/null 2>&1
then
	echo "UNKNOWN - Unable to resolve $DBHOST"
	exit 3
elif [ -z "$DBUSER" ] || [ -z "$DBPASS" ] || [ -z "$DATABASE" ]
then
	usage
elif [ -z $MINUTES ]
then
	usage
elif echo $MINUTES | egrep '[a-z]|[A-Z]' > /dev/null
then
	usage
elif [ -z "$WARNING" ] || [ -z "$CRITICAL" ]
then
	usage
elif echo $WARNING | egrep '[a-z]|[A-Z]' > /dev/null
then
	usage
elif echo $CRITICAL | egrep '[a-z]|[A-Z]' > /dev/null
then
	usage
fi


# Set MYSQL command
MYSQL="mysql -h $DBHOST -u $DBUSER -p$DBPASS $DATABASE --skip-column-names -s -e"


# Set dates
CURRENT=$(date "+%Y-%m-%d %H:%M:%S")
LAST_X_MINUTES=$(date -d "- $MINUTES minute" "+%Y-%m-%d %H:%M:%S")


# Run query and store the result
RESULT=$($MYSQL "SELECT COUNT(DISTINCT USER_U_ID) FROM SNG_ACTIVITY_LOG WHERE USER_U_ID!='null' AND EVENT_CODE = '10301' AND EVENT_TIME>=cast('$LAST_X_MINUTES' AS DATETIME) AND EVENT_TIME<cast('$CURRENT' AS DATETIME);" 2>&1)


# Report result
if echo $RESULT | egrep '[a-z]|[A-Z]' > /dev/null
then
	echo "UNKNOWN - $RESULT"
	exit 3
elif [ "$RESULT" -le "$CRITICAL" ]
then
	echo "CRITICAL - $RESULT Login's in the last $MINUTES minutes"
	exit 2
elif [ "$RESULT" -le "$WARNING" ]
then
        echo "WARNING - $RESULT Login's in the last $MINUTES minutes"
        exit 1
else
        echo "OK - $RESULT Login's in the last $MINUTES minutes"
        exit 0
fi
