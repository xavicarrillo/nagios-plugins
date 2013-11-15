#!/bin/bash
# NFS mount plugin for Nagios
# Written by Tim Gibbon nagios-plugin@chegwin.org
# Last Modified: 24-Mar-2007
#
# Description:
#
# This plugin will check the status of a remote servers NFS shares.
#
# Add the following to checkcommands.cfg
#define command {
#        command_name check_nfsmount
#        command_line $USER1$/check_nfsmount -H $HOSTADDRESS$
#        }
# Add the following to your main nagios cfg
#
#define service{
#        use                             generic-service
#        host_name                       nfsserver
#        service_description             NFS shares
#        is_volatile                     0
#        check_period                    24x7
#        max_check_attempts              4
#        normal_check_interval           5
#        retry_check_interval            1
#        contact_groups                  linux-admins
#        notification_interval           960
#        notification_period             24x7
#        notification_options            c,r
#        check_command                   check_nfsmount
#        }
#
#




# Location of the showmount command (if not in path)
SHOWMOUNT="/usr/sbin/showmount"


# Don't change anything below here

# Nagios return codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

if [ ! -x "${SHOWMOUNT}" ]
then
	echo "UNKNOWN: $SHOWMOUNT not found or is not executable by the nagios user"
	exitstatus=$STATE_UNKNOWN
	exit $exitstatus
fi

PROGNAME=`basename $0`

print_usage() {
	echo "Usage: $PROGNAME -H <hostname>"
	echo ""
	echo "Notes:"
	echo "-H: Hostname - Can be a hostname or IP address"
	echo ""
}

print_help() {
	print_usage
	echo ""
	echo "This plugin will check the NFS mounts on a remote (or local with -H localhost) NFS server."
	echo ""
	exit 0
}


#exitstatus=${STATE_UNKNOWN} #default

while test -n "$1"; do
	case "$1" in
		--help)
			print_help
			exit $STATE_OK
			;;
		-h)
			print_help
			exit $STATE_OK
			;;
		-H)
			HOSTNAME=$2
			shift
			;;
		*)
			print_help
			exit $STATE_OK
	esac
	shift
done

# Check arguments for validity
if [ -z ${HOSTNAME} ]
then
	echo "You must specify a hostname (or localhost to test the local system)"
	print_usage
	exitstatus=$STATE_UNKNOWN
	exit $exitstatus
fi

# Remove the wildcards as they cause a complete listing of CWD
SHOWMOUNT_OUTPUT=`${SHOWMOUNT} -e ${HOSTNAME} 2>&1`

if [ $? -ne 0 ]
then
exitstatus=${STATE_CRITICAL}
else
exitstatus=${STATE_OK}
fi

CLEANED_SHOWMOUNT_OUTPUT=`${SHOWMOUNT} -e ${HOSTNAME} 2>&1 | sed -e s/\*//g`
# Remove the wildcards as they cause a complete listing of CWD

echo ${CLEANED_SHOWMOUNT_OUTPUT}
exit $exitstatus
