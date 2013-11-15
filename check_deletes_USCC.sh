#!/bin/bash

# how many files we expect to see
EXPECTCOUNT=6
MASTER=nbg2-uscc-be-01

hour=`date +%H`
FOLDER=/opt/domain/app/user-deletes/CURRENT
LOGS=${FOLDER}/logs
DATS=${FOLDER}/files

COMPAREHOUR=16

if [ $HOSTNAME != $MASTER ]; then
echo Running on slave. 
exit 0
fi

if [ $hour -lt ${COMPAREHOUR} ]; then
echo Before ${COMPAREHOUR} :00 - No files to run!
exit 0
fi

DATE=`date +%m%d%Y`

datCount=`ls ${DATS}/${DATE}*.dat 2> /dev/null | wc -l`
logCount=`ls ${LOGS}/${DATE}*.log 2> /dev/null | wc -l`

if [ ${datCount} -ne ${EXPECTCOUNT} ]; then
echo Data files not received - expected ${EXPECTCOUNT} - got ${datCount} - READ WIKI
exit 2
fi

if [ ${logCount} -ne ${EXPECTCOUNT} ]; then
echo Log files not generated - expected ${EXPECTCOUNT} - got ${logCount} - READ WIKI
exit 2
fi

echo DELETES OK - Data files - ${datCount} - Log files: ${logCount}
exit 0
