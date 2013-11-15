#!/bin/bash

#
# This script gets stats, by query type, for the last X Minutes
#
# Query Types:
#
# 1 - Login's
# 2 - Registrations
#
#
# Several arguments need to be passed for this script to work
# See "usage" for more details
#
# NOTE: This script expects CRITICAL to always be lower than WARNING
#
#


#--------------
#  VARIABLES
#--------------

# DEFINE PROJECTS TO HANDLE
PROJECTS_ARRAY=( mocuk mocpt moces )


#--------------
#  FUNCTIONS  
#--------------

usage () {
        echo "UNKNOWN - Usage: $0 -project (project) -q (query type) -h (db host) -u (db user) -p (db password) -d (database) -m (minutes) -w (warning) -c (critical)"
        exit 3
}



#--------------
#     MAIN   
#--------------

for LOOP
do
	case $1 in

	-project)
		PROJECT=$2
		shift 2
		;;
	-q)
		QTYPE=$2
		shift 2
		;;
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



# Validate Arguments (QTYPE is validated in case cycle below)

if [[ ! `echo ${PROJECTS_ARRAY[*]}` =~ $PROJECT ]]
then
	usage
elif [[ -z $DBHOST ]]
then
	usage
elif ! host $DBHOST > /dev/null 2>&1
then
	echo "UNKNOWN - Unable to resolve $DBHOST"
	exit 3
elif [[ -z "$DBUSER" ]] || [[ -z "$DBPASS" ]] || [[ -z "$DATABASE" ]]
then
	usage
elif [[ -z $MINUTES ]]
then
	usage
elif [[ $MINUTES =~ [:alpha:] ]]
then
	usage
elif [[ -z "$WARNING" ]] || [[ -z "$CRITICAL" ]]
then
	usage
elif [[ $WARNING =~ [:alpha:] ]]
then
	usage
elif [[ $CRITICAL =~ [:alpha:] ]]
then
	usage
fi


# Set MYSQL command
MYSQL="mysql -h $DBHOST -u $DBUSER -p$DBPASS $DATABASE --skip-column-names -s -e"


# Set dates
CURRENT=$(date "+%Y-%m-%d %H:%M:%S")
LAST_X_MINUTES=$(date -d "- $MINUTES minute" "+%Y-%m-%d %H:%M:%S")


# Run query and store the result - break if QTYPE not valid
case $QTYPE in

1)
	RESULT=$($MYSQL "SELECT COUNT(DISTINCT USER_U_ID) FROM SNG_ACTIVITY_LOG WHERE USER_U_ID!='null' AND EVENT_CODE = '10301' AND EVENT_TIME>=cast('$LAST_X_MINUTES' AS DATETIME) AND EVENT_TIME<cast('$CURRENT' AS DATETIME);" 2>&1)
	;;
2)
	# Run specific query types per project (eg: MOC UK gets Registrations from ACS while MOC PT & ES get from SNG)
	case $PROJECT in

		mocuk)
			RESULT=$($MYSQL "SELECT COUNT(DISTINCT phone_number) FROM acs_user_account WHERE insert_time>=cast('$LAST_X_MINUTES' AS DATETIME) AND insert_time<cast('$CURRENT' AS DATETIME);" 2>&1)
			;;
		*)
			RESULT=$($MYSQL "SELECT COUNT(DISTINCT USER_U_ID) FROM SNG_SESSION WHERE DELETED='0' AND USER_U_ID!='null' AND DATE_CREATED>=cast('$LAST_X_MINUTES' AS DATETIME) AND DATE_CREATED<cast('$CURRENT' AS DATETIME);" 2>&1)
			;;
	esac
	;;
*)
	usage
	;;
esac


# Report result
if echo $RESULT | egrep '[a-z]|[A-Z]' > /dev/null
then
	echo "UNKNOWN - $RESULT"
	exit 3
elif [ "$RESULT" -le "$CRITICAL" ]
then
	echo "CRITICAL - $RESULT in the last $MINUTES minutes"
	exit 2
elif [ "$RESULT" -le "$WARNING" ]
then
        echo "WARNING - $RESULT in the last $MINUTES minutes"
        exit 1
else
        echo "OK - $RESULT in the last $MINUTES minutes"
        exit 0
fi
