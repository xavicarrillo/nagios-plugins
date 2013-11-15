#!/bin/bash
#
# Event Handler Script for Service Actions
#
# This scipt will perform an action against a service if it matches a specific condition in the variables below.
#
# Important: You need to create a server-specific configuration file to define what actions should be actually performed.
# Example: If the server-name is "orange-bebo-fe1", create a config file called: orange-bebo-fe1_eventhandler.cfg
#          and define matching conditions and actions inside that file.
#
#
# NOTE: This variables are provided by nagios. We will use the same variables here for consistence
#
# $1 = $SERVICESTATE$ : OK|WARNING|UNKNOWN|CRITICAL			# The service state
# $2 = $SERVICESTATETYPE$ : SOFT|HARD 					# The type of the service state (soft happens before notifications are sent)
# $3 = $SERVICEATTEMPT$ :  1|2|3|(...)					# The number of the check attempt being performed
# $4 = $HOSTNAME$ : orange-bebo-gw2|orange-bebo-fe2|(...)		# The same as config file
# $5 = $SERVICEDESC$ : Process: Tomcat |/usr/local|Load Average|(...) 	# The same as config file
# $6 = $SERVICEDOWNTIME$ : 0 | 1 					# 0 = No Downtime scheduled -- 1 = Downtime scheduled
#
# Created by: Bruno Condez
#

# ---------------
#    Variables
# ---------------

SERVICESTATE=$1
SERVICESTATETYPE=$2
SERVICEATTEMPT=$3
HOSTNAME=$4
SERVICEDESC=$5
SERVICEDOWNTIME=$6

ARGS_NUMBER=6 # Total number of arguments
ARGS_LIST="$1 $2 $3 $4 $5" # Aggregate arguments (usefull for logging)

TIMEOUT=30 # Timeout of NRPE Command in seconds
CONFIGDIR="/usr/lib/nagios/plugins/eventhandlers" # Directory that contains server-specific config files
NRPEDIR="/usr/lib/nagios/plugins"
LOGFILE=/var/log/nagios/eventhandler/${HOSTNAME}.log # Logfile to report
REPORT_EMAIL="ops_support@domain.com us-support@domain.com" # Email(s) to report
NAGIOSCMD=/var/spool/nagios/cmd/nagios.cmd # Nagios CMD to pipe commands
READ_GENERIC_CFG=0 # Read the generic config file - 0=No  1=Yes


# ---------------
#   Functions
# ---------------

# Log
report () {

echo "`date` - Arguments: $ARGS_LIST $6 || Action: $ACTION" $EXTRAINFO_BODY | tee -a $LOGFILE

cat << EOF | mail -s "Nagios Event Handler - Action performed on $HOSTNAME $EXTRAINFO_SUBJECT" $REPORT_EMAIL
$EXTRAINFO_BODY

Date: `date`
Host: $HOSTNAME
Service Description: $SERVICEDESC
Service State: $SERVICESTATE
Service State Type: $SERVICESTATETYPE
Service Attempt: $SERVICEATTEMPT

Action Performed: 
$ACTION

$OUTPUT


Log file: $LOGFILE
Sent by: Nagios (EventHandler)
EOF


# Since we already did something on the remote server, (don't) load generic config file.
# This allows to overwrite generic alarms with server-spceific ones.
READ_GENERIC_CFG=0

}

# Performs an action on the remote server
perform () {

#Is downtime scheduled for this service?
[[ "$SERVICEDOWNTIME" -ne "0" ]] && { echo "`date` - Arguments: $ARGS_LIST $6 || Action: NONE --> Reason: Downtime scheduled for this service" | tee -a $LOGFILE; exit; }

ACTION=$1

# CHECK_NRPE can only print one line of output from the script it runs remotely.
# Currentely installed version 2.7 has this limitation, however version 2.12 has this fixed.
# To workaround this limitation, we send the "$ACTION" output into a file in "/scratch", on the remote server. 
# Then on this server we send the file content into the variable "$OUTPUT"
$NRPEDIR/check_nrpe -H $HOSTNAME -n -t $TIMEOUT -c EH_perform -a "$ARGS_LIST" "$SERVICEDESC" "$ACTION" $REMOTEUSER > /scratch/.${HOSTNAME}_nrpe.output 2>&1

# If output file exists assing it to variable. If not, report an error
[[ -r "/scratch/.${HOSTNAME}_nrpe.output" ]] && OUTPUT=`cat /scratch/.${HOSTNAME}_nrpe.output` || OUTPUT="Unable to find output file in /scratch"
report
}


# Performs an alert on the remote server
alert () {

$NRPEDIR/check_nrpe -H $HOSTNAME -n -c EH_alert -a "$ARGS_LIST" "$SERVICEDESC"


# Since we already did something on the remote server, (don't) load generic config file.
# This allows to overwrite generic alarms with server-specific ones.
READ_GENERIC_CFG=0
}


# ---------------
#     MAIN
# ---------------

# Validate number of arguments
[[ "$#" -ne "$ARGS_NUMBER" ]] && { echo "Invalid number of arguments - Expected $ARGS_NUMBER, Provided: $#"; exit 99; }


# Source/Execute Config Files (First: Server-specific - Second: Generic)
. $CONFIGDIR/${HOSTNAME}_eventhandler.cfg
[[ "$READ_GENERIC_CFG" -eq "1" ]] && . $CONFIGDIR/generic_eventhandler.cfg

exit $?
