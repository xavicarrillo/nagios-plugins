#!/bin/bash
#
# Description: check the messages in each queue for SwiftMQ and display the results
# Dependencies: 
#	- SwiftMQ
#	- JVM
#	- clis.sh
#	- allqueues-dyna.cli (content at the bottom of this file):  ALLQDYNA
# 
# Author: Adrian Turcu <adriant@domain.com>
# Version: 1.0.3
# 


LOCKFILE="/tmp/status-dynaq.lck"

# Check of the lock file exists == another instance is running
if [ -f "$LOCKFILE" ]
then

cat << EOF

Another instance of this script is running or it crashed the last time.
If you are absoltely sure that no other instace is running, remove the lock file $LOCKFILE
 and re-run this script.

EOF

exit 1
fi


## no other instance is running, lock this one
touch $LOCKFILE

## clis.sh full path
CLISH="/opt/domain/bin/swiftmq/clis.sh"

## allqueues-dyna.cli full path
ALLQDYNA="/opt/domain/bin/swiftmq/allqueues-dyna.cli"

## file to store all queue names
DYNAQFILE="/tmp/dynaq.out"

## get all queue names into $DYNAQFILE file for further processing
## we don't check testqueue and we remove the line "Description: Active Queues"
$CLISH $ALLQDYNA | grep -i queue | egrep -v '^testqueue|^Description' > $DYNAQFILE


## SwiftMQ scriptlet with all dynamic queues
DYNACLI="/tmp/allqueues-dyna.cli"

## Populate the scriptlet
echo "sr router1" > $DYNACLI
cat $DYNAQFILE | awk '{print "lc sys$queuemanager/usage/" $1}' >> $DYNACLI
echo "exit" >> $DYNACLI


## Read the status of each queue (names are not provided by this)
STATUS=`$CLISH $JMSUSER $JMSPASSWORD $DYNACLI | grep -i messagecount | cut -c 41-`

## Build the queue names array
QUEUE=( `cat $DYNAQFILE | tr '\n' ' '`)


## Iterate through the status and append the name of the queue
I=0
for STAT in $STATUS
do
  echo ${QUEUE[$I]} : $STAT
  let "I += 1"
done


rm -f $LOCKFILE
rm -f $DYNAQFILE
rm -f $DYNACLI

exit 0


### allqueues-dyna.cli ###

cat << EOF

sr router1
lc sys$queuemanager/usage
exit

EOF

