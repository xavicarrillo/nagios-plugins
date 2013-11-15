#!/bin/bash
#
# Description: check the messages in each queue for SwiftMQ and display the results
# Dependencies: 
#	- SwiftMQ
#	- JVM
#	- clis.sh (content at the bottom of this file): CLISH
#	- allqueues-dyna.cli (content at the bottom of this file):  ALLQDYNA
# 
# Author: Adrian Turcu <adriant@domain.com>
# Version: 1.0
# 


SWIFTDIR=/usr/local/swiftmq
#CLISHDIR="$SWIFTDIR/scripts/unix"
#CLISH="clis"
CLISHDIR="$SWIFTDIR/scripts/custom_swiftmq"
CLISH="clis.sh"
ALLQDYNA="/usr/lib/nagios/plugins/domain/swiftmq/allqueues-dyna.cli"
DYNAQFILE="/tmp/dynaq.out" ## file to store all queue names
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

# set up the java environment variables
. /opt/domain/etc/jvmrc

## get all queue names into $DYNAQFILE file for further processing
## we don't check testqueue and we remove the line "Description: Active Queues"
cd $CLISHDIR
./$CLISH $ALLQDYNA | grep -i queue | egrep -v '^testqueue|^Description' > $DYNAQFILE


## SwiftMQ scriptlet with all dynamic queues
DYNACLI="/tmp/allqueues-dyna.cli"

## Populate the scriptlet
echo "sr router1" > $DYNACLI
cat $DYNAQFILE | awk '{print "lc sys$queuemanager/usage/" $1}' >> $DYNACLI
echo "exit" >> $DYNACLI


## Read the status of each queue (names are not provided by this)
STATUS=`cd $CLISHDIR && ./$CLISH $DYNACLI | grep -i messagecount | cut -c 41-`

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
exit 0



### clis.sh ###
cat << EOF

#!/bin/sh

SWIFTROOT=/etc/alternatives/swiftmq
SJAR=$SWIFTROOT/jars
SWIFTRUN=$SWIFTROOT/scripts/unix

SWIFTURL=smqp://localhost:4001
SWIFTCF=plainsocket@router1

if [ -z $JAVA_HOME ]; then . /etc/java/java.conf; fi
export CLASSPATH=$SJAR/swiftmq.jar:$SJAR/jndi.jar:$SJAR/jms.jar:$SJAR/jsse.jar:$SJAR/jnet.jar:$SJAR/jcert.jar

exec $JAVA_HOME/bin/java -Dcli.username=admin -Dcli.password=secret com.swiftmq.admin.cli.CLI $SWIFTURL $SWIFTCF $1

EOF


### allqueues-dyna.cli ###

cat << EOF

sr router1
lc sys$queuemanager/usage
exit

EOF

