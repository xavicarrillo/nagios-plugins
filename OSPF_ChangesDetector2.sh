#!/bin/bash
#
# This alarm will detect the Open Shortest Path First (OSPF) neighbour failures, aka dead peers
#
# NO "Dead timer expired" -> OK
# "Dead timer expired" + 'LOADING to FULL, Loading Done' -> OK
# "Dead timer expired" without 'LOADING to FULL, Loading Done' -> CRITICAL
#
# xcarrillo@domain.com
#

PLUGINSDIR="/usr/lib/nagios/plugins"
LOGFILE="/var/log/all-logs.log"
. $PLUGINSDIR/utils.sh


#Example:
#Jan  1 12:14:58 93.174.168.3 10253: 010258: Jan  1 12:14:58.116: %OSPF-5-ADJCHG: Process 64529, Nbr 93.174.168.4 on GigabitEthernet0/2 from 2WAY to DOWN, Neighbor Down: Dead timer expired
IsNeighborDown=`egrep '%OSPF-5-ADJCHG.*Dead timer expired' $LOGFILE |tail -1`
if [ "$IsNeighborDown" = '' ]
then
	#if No "Dead timer expired" is found, OK
        exitstatus=${STATE_OK}
        statusmessage="OK: no OSPF neighbour failures"
else
	#Else, we have to check if it was reloaded afterwards. Example:
	#Jan  1 12:17:15 93.174.168.1 145658: 145614: Jan  1 12:17:15.713: %OSPF-5-ADJCHG: Process 64529, Nbr 93.174.168.4 on Vlan101 from LOADING to FULL, Loading Done
	NeighborDownIP=`echo $IsNeighborDown | awk {'print $14'}`
	IsLoaded=`egrep 'LOADING to FULL, Loading Done' $LOGFILE | grep $NeighborDownIP | tail -1`
	if [ "$IsLoaded" = '' ]
	then
		# If after a 'Dead timer expired' message there is NOT a "LOADING to FULL, Loading Done" message for the same IP, it didn't recover. So CRITICAL
		exitstatus=${STATE_CRITICAL}
		statusmessage="CRITICAL: there is an OSPF neighbour failure for the IP $NeighborDownIP"
	else
		# If the 'Loading Done' message is there, we have to check that it occured after the 'Dead timer expired',
		# therefore the difference of times have to be negative.
		IsLoadedDate=`echo $IsLoaded | awk {'print $1" "$2" "$3'}`
		IsLoadedTimeStamp=`date --utc --date "$IsLoadedDate" +%s`
		NeighborDownDate=`echo $IsNeighborDown | awk {'print $1" "$2" "$3'}`
		NeighborDownTimeStamp=`date --utc --date "$NeighborDownDate" +%s`
		let "TimeDifference=$NeighborDownTimeStamp-$IsLoadedTimeStamp"
		echo $TimeDifference
		if [ $TimeDifference -lt 0 ]
		then
			# If this issue happened 10 minutes ago or more, we just quit with an OK. Otherwise, we send a warning.
			# In both cases the issue was fixed, but we want to make sure that a warning has been sent so this can be investigated afterwards.
			# But we don't want to be sending alarms until the logs are rotated, that's why we give this 10 min period of grace. (So only 2 warnings will be sent).
			CurrentTime=`date --utc --date="now" +%s`
			let "TimeDifference=$CurrentTime - $IsLoadedTimeStamp"
			if [ $TimeDifference -gt 600 ]
			then
	                        exitstatus=${STATE_OK}
	                        statusmessage="OK: No dead peers found"
			else
				# After a 'Dead timer expired' message there is a "LOADING to FULL, Loading Done" for the same IP, so it recovered,
				# but we quit with a WARNING because this needs to be investigated.
				exitstatus=${STATE_WARNING}
				statusmessage="WARNING: There was an OSPF neighbour failure, although it was fixed in $TimeDifference seconds"
				statusmessage="NeighborDownDate is $NeighborDownDate and IsLoadedDate=$IsLoadedDate and time is $TimeDifference"
			fi
		fi # If it's positive it means the 'Loading Done' was before the 'Dead time expired' so it is meaningless.
	fi
fi

echo $statusmessage
#echo "and NeighborDownTimeStamp is $NeighborDownTimeStamp and IsLoadedTimeStamp is $IsLoadedTimeStamp"
echo "IsNeighborDown is $IsNeighborDown"
echo "$IsLoaded is $IsLoaded"
exit $exitstatus

