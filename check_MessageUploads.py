#!/usr/bin/env python
# -*- coding: utf-8 -*-
#

"""
Controls the average of messages uploaded, querying to a database. Besides, it returns perfdata to be used with nagios-graph
Requirements: yum install MySQL-python
"""

__title__ = "check_Messages"
__version__ = "0.6"
__author__= "Xavi Carrillo"
__email__= "xcarrillo at domain dot com"

import sys
import MySQLdb
import datetime
from optparse import OptionParser

def main():
	# SQL queries are defined here. Use START as the keyword for the first date, it will be changed later in the script for the correct value
	# So all queries should end with "BETWEEN 'START' AND NOW()"
	# the first value is the name used with the --query parameter
	dictionary = {
	'orangemoc-es_SMSIN':\
	"SELECT COUNT(DISTINCT USER_U_ID,EVENT_TIME) FROM SNG_ACTIVITY_LOG WHERE CHANNEL='SMS'\
	AND EVENT_CODE!='10101' AND EVENT_CODE!='10106' AND EVENT_TIME BETWEEN 'START' AND NOW()",\

	'orangemoc-es_SMSOUT':"SELECT COUNT(*) FROM SNG_ACTIVITY_LOG WHERE CHANNEL='SMS'\
	AND EVENT_CODE='10101' AND EVENT_TIME BETWEEN 'START' AND NOW() OR EVENT_CODE='10106' AND EVENT_TIME BETWEEN 'START' AND NOW()", \

	'orangemoc-es_MMSIN':"SELECT COUNT(DISTINCT USER_U_ID, EVENT_TIME) FROM SNG_ACTIVITY_LOG WHERE EVENT_CODE='10201'\
	AND CHANNEL='MMS' AND EVENT_TIME BETWEEN 'START' AND NOW()", \

	'orangemoc-es_MediaSent2SNS':"SELECT COUNT(*) FROM SNG_ACTIVITY_LOG WHERE EVENT_CODE='10202' AND RESPONSE_STATUS='1' AND EVENT_TIME BETWEEN 'START' AND NOW()",\

	'linkbook':"SELECT COUNT(DISTINCT ID) FROM SNG_ACTIVITY_LOG WHERE EVENT_CODE='10202' AND RESPONSE_STATUS='1' AND EVENT_TIME BETWEEN 'START' AND NOW()",\

	'tmobile-clw':"SELECT COUNT(DISTINCT ID) FROM SNG_SNS_MEDIA_UPLOAD WHERE STATUS = '1' AND DATE_CREATED BETWEEN 'START' AND NOW()"
	}

        usage = "\t Usage: %prog [options]\n \
	Gets the number of uploads and returns a Nagios status code if the warning/critical numbers are not reached. \n \
	The query to get that number has to be provided with the -q parameter (so we can use the script for every project) but removing the 'BETWEEN date1 AND date2' part \n \
	which is calculated later taking the number of minutes passed in '--time' \n \n \
	Examples: \n \
	Use --help to view options"

        parser = OptionParser(usage, version=__version__)
        parser.add_option("-v", "--vip", action="store", dest="vip", type="string", help="MySQL server VIP")
        parser.add_option("-u", "--username", action="store", dest="username", type="string", help="MySQL username")
        parser.add_option("-p", "--password", action="store", dest="password", type="string", help="MySQL password")
        parser.add_option("-d", "--database", action="store", dest="database", type="string", help="MySQL database name")
        parser.add_option("-q", "--query", action="store", dest="query", type="string", help="name of the project that we want to use. It is defined within the 'dictionary' variable")
        parser.add_option("-t", "--time", action="store", dest="time", type="int", help="Number of minutes in the past")
        parser.add_option("-w", "--warning", action="store", dest="warning", type="int", default=None, help="warning threshold")
        parser.add_option("-c", "--critical", action="store", dest="critical", type="int", help="critical threshold")
        parser.add_option("--average", action="store_true", dest="average", default=False, help="Instead of looking at the number of uploads, the average per minute is counted.")
        parser.add_option("--hours", action="store_true", dest="hours", default=False, help="The performance data is returned in hours instead of minutes.")
                          
        (options, args) = parser.parse_args()

        ### Argument parsing ###
        if not options.vip:
                parser.error("VIP is mandatory")
        if not options.username:
                parser.error("username is mandatory")
        if not options.password:
                parser.error("password is mandatory")
        if not options.database:
                parser.error("database is mandatory")
        if not options.query:
                parser.error("query is mandatory")
        if not options.time:
                parser.error("time is mandatory")
	if options.warning:
		if options.warning < options.critical:
			parser.error("critical has to be less than warning")
        if options.query not in dictionary:
                print "error: Query not recognized. Available queries are: "
                for item in dictionary.iteritems():
                        print item[0]
                sys.exit(2)

	seconds = options.time*60 # We need the minutes to be converted to seconds, since unix timestamp is in seconds.
	if options.time < 60:
		hours = 0
	else:
		hours = options.time/60

        try:
		conn = MySQLdb.connect (host=options.vip,user=options.username,passwd=options.password,db=options.database)
		cursor = conn.cursor()
        except MySQLdb.Error,e :
     		print "Error %d: %s" % (e.args[0], e.args[1])
		sys.exit (2)

	if options.hours == True:
                past_time = datetime.timedelta(hours=hours)
	else:
                past_time = datetime.timedelta(seconds=seconds)

	now = datetime.datetime.now()
	firstdate = now - past_time

	# We format the query string by grabing the SQL from the dictionary and substituting the word START by the time we want to check.
        query = dictionary[options.query].replace('START',str(firstdate)) 
	cursor.execute(query);
	row = cursor.fetchone()
	last_messages = row[0]
        
        if options.hours == True:
		average = last_messages/hours #messages per hour
	else:
		average = last_messages/options.time #messages per minute


	# if --average is set, we consider the average number of messages per minute or per hour to decide if we have a critical, warning or ok
	# otherwise, we just check the number of messages in the last give messages.
	if options.average == True and options.hours == False:
		threshold = average_per_minute
	elif options.average == True and options.hours == True:
		threshold = average_per_hour
	else:
		threshold = last_messages

        if threshold >= options.warning:
               	exitstatus = 0
	        statusmsg = "OK"

	if threshold < options.warning:
		exitstatus = 1
		statusmsg = "WARNING"

	if threshold <= options.critical:
		exitstatus = 2
		statusmsg = "CRITICAL"

        if options.hours == True:
		# We return the perfdata in hours instead of minutes
                print 'Uploaded Messages %s: %d uploads in the last %d hours|uploads=%d;%d;%d' %(statusmsg,last_messages,hours,last_messages,options.warning,options.critical)
        else: 
		# We return the perfdata in minutes instead of hours 
        	print 'Uploaded Messages %s: %d uploads in the last %d min|uploads=%d;%d;%d' %(statusmsg,last_messages,options.time,last_messages,options.warning,options.critical)
	
	cursor.close()
	conn.close()
	sys.exit (exitstatus)

if __name__ == "__main__":
        main()

