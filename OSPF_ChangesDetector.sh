#!/bin/bash
#
# This alarm will detect the Open Shortest Path First (OSPF) neighbour failures, aka dead peers
#
# NO "Dead timer expired" -> OK
# "Dead timer expired" + 'LOADING to FULL, Loading Done' -> OK
# "Dead timer expired" without 'LOADING to FULL, Loading Done' -> CRITICAL
#
# Example:
# Jan 1 12:14:58 93.174.168.3 10253: 010258: Jan  1 12:14:58.116: %OSPF-5-ADJCHG: Process 64529, Nbr 93.174.168.4 on GigabitEthernet0/2 from 2WAY to DOWN, Neighbor Down: Dead timer expired
# Jan 1 12:17:15 93.174.168.1 145658: 145614: Jan  1 12:17:15.713: %OSPF-5-ADJCHG: Process 64529, Nbr 93.174.168.4 on Vlan101 from LOADING to FULL, Loading Done
#
# xcarrillo@domain.com
#

PLUGINSDIR="/usr/lib/nagios/plugins"
LOGFILE="/var/log/all-logs.log"
. $PLUGINSDIR/utils.sh


# We grep the latest Dead Peer error in the log file, but only for the events logged in the last 10 minutes

PAST=`date --date "10 minutes ago" +%d" "%H:%M`
FIRST_LINE_NUMBER=`grep -an "$PAST" $LOGFILE | head -1 | awk -F: {'print $1'}` #which is the number of the 1st line begining with that time?
LAST_LINE_NUMBER=`cat $LOGFILE | wc -l` #number of the last line of the logfile
FIRST_LINE_NUMBER_SIZE=`echo $FIRST_LINE_NUMBER | wc -w`
LINES2SHOW=$(($LAST_LINE_NUMBER-$FIRST_LINE_NUMBER)) 
NEIGHBOR_DOWN=`tail -$LINES2SHOW $LOGFILE | egrep '%OSPF-5-ADJCHG.*Dead timer expired' | grep -v nagios | tail -1`

if [ "$NEIGHBOR_DOWN" = '' ]
then
	# If No "Dead timer expired" is found, OK
        EXITSTATUS=${STATE_OK}
        STATUSMESSAGE="OK: No dead peers found | 'seconds'=0"
else
	# If it is found, we have to check if it was reloaded afterwards, within the same timeperiod (10 min ago), and for the same IP
	# Ex: Jan  1 12:17:15 93.174.168.1 145658: 145614: Jan  1 12:17:15.713: %OSPF-5-ADJCHG: Process 64529, Nbr 93.174.168.4 on Vlan101 from LOADING to FULL, Loading Done

	NEIGHBOR_DOWN_IP=`echo $NEIGHBOR_DOWN | awk {'print $14'}`
	LOADED=`tail -$LINES2SHOW $LOGFILE | egrep 'from LOADING to FULL, Loading Done' | grep "Nbr $NEIGHBOR_DOWN_IP" | tail -1`
	NOW=`date --utc --date "now" +%s`
	NEIGHBOR_DOWN_DATE=`echo $NEIGHBOR_DOWN | awk {'print $1" "$2" "$3'}`
	NEIGHBOR_DOWN_TIMESTAMP=`date --utc --date "$NEIGHBOR_DOWN_DATE" +%s`
	let "TIME_DOWN=$NEIGHBOR_DOWN_TIMESTAMP-$NOW"

	if [ "$LOADED" = '' ]
	then
		# If after a 'Dead timer expired' there is NOT a "LOADING to FULL, Loading Done" for the same IP, it didn't recover. So CRITICAL
		EXITSTATUS=${STATE_CRITICAL}
		STATUSMESSAGE="CRITICAL: there is an OSPF neighbour failure for the IP $NEIGHBOR_DOWN_IP | 'seconds'=$TIME_DOWN"
	else
		# If the 'Loading Done' message is there, we have to check that it occured after the 'Dead timer expired',
		# therefore the difference of times have to be negative.

		LOADED_DATE=`echo $LOADED | awk {'print $1" "$2" "$3'}`
		LOADED_TIMESTAMP=`date --utc --date "$LOADED_DATE" +%s`

		let "TIME_DIFFERENCE=$LOADED_TIMESTAMP - $NEIGHBOR_DOWN_TIMESTAMP"
		echo $NEIGHBOR_DOWN
		echo $LOADED

		if [ $TIME_DIFFERENCE -lt 0 ]; then
			# If it's negative it means that the 'Loading Done' was before the 'Dead time expired' so it refers to another failure.
			# Therefore, the neighbor is still down
        	        EXITSTATUS=${STATE_CRITICAL}
	                STATUSMESSAGE="CRITICAL: there is an OSPF neighbour failure for the IP $NEIGHBOR_DOWN_IP | 'seconds'=$TIME_DOWN"
		else
			# After a 'Dead timer expired' message there is a "LOADING to FULL, Loading Done" for the same IP, so it recovered,
			# We exit witha an OK, but with a different message, saying when the failure happend, and how many seconds it toke to recover.
			EXITSTATUS=${STATE_OK}
			STATUSMESSAGE="OK: There was an OSPF neighbour failure at $NEIGHBOR_DOWN_DATE and was fixed in $TIME_DIFFERENCE sec | 'seconds'=$TIME_DIFFERENCE"

		fi 
	fi
fi

echo $STATUSMESSAGE
exit $EXITSTATUS

