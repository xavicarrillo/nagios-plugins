#!/bin/bash
###############################################################################################################################################################
# We have 2 nagios instances, nbg2-nagios01 and nbg2-nagios02. By default, nagios01 is up, and nagios02 is down.
# There should only be one Nagios instance running at the same time, to avoid duplicate checks. 
# This script is running every 5 minutes on each host. It checks if the other nagios peer is up or not.
# So let's say nbg2-nagios01 goes down. nbg2-nagios02 cron will notice that and start its own nagios (that shares the configuration with 01).
# If after the failover 02 goes down too, they both will be down so the first cron that executes this script will start nagios on that host.
# Also, it can happen that between 2 and 3 minutes both are down and both scripts start them up. So if the two of them are up, we shut down the local one.
###############################################################################################################################################################

remote_nagios_host=$1
localhost=`/bin/hostname`

contactemail="ops_support@domain.com"
message="Nagios server at $localhost failed-over $remote_nagios_host"
mail_program="/etc/nagios/shared/bin/pymail"
sms_program="/etc/nagios/shared/bin/mxtelecom-send-sms"

plugins_dir="/usr/lib/nagios/plugins/"

$plugins_dir/check_nrpe -n -H $remote_nagios_host -c check_nagios >/dev/null 2>&1
remote_nagios_status=$?
$plugins_dir/check_nagios /var/log/nagios/status.dat 5 '/usr/sbin/nagios' >/dev/null 2>&1
local_nagios_status=$?

. $plugins_dir/utils.sh
exitstatus=${STATE_UNKNOWN}
statusmessage="UNKNOWN"


function send_notification
{
	# Send email to operations
	$mail_program -f $localhost@domain.com \
		      -t $contactemail \
 		      -s "$message" \
		      -m "$message"

	# Send an SMS to the oncall guys
	for number in `grep pager /etc/nagios/shared/definitions/contacts.cfg |grep -v notify|grep -v "#"|awk {'print $2'}`
	do
		/usr/bin/printf "$message" | $sms_program $number $localhost "$message"
	done
}

if [[ $local_nagios_status = ${STATE_CRITICAL} ]] && [[ $remote_nagios_status = ${STATE_CRITICAL} ]]
then
	# Both are down, we start this one
        /etc/init.d/nagios start
	send_notification
        exitstatus=${STATE_CRITICAL}
        statusmessage="CRITICAL"
elif [[ $local_nagios_status = ${STATE_OK} ]] && [[ $remote_nagios_status = ${STATE_OK} ]]
then
        # Both are UP so we stop this one. We don't care which one is up, they share all the configuration files.
	/etc/init.d/nagios stop
        send_notification
else
	exitstatus=${STATE_OK}
	statusmessage="OK"
fi

echo "$statusmessage"
exit $exitstatus


