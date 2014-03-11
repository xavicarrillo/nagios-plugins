#!/usr/bin/env python
# -*- coding: utf-8 -*-
#

"""
Nagios plugion to check logs for a given string
"""

__title__ = "check_messagelogs.py"
__version__ = "0.5"
__author__= "Xavi Carrillo"
__email__= "xcarrillo at domain dot com"
__changelog__="Added the --delta option"
__licence__="""
Copyright (c) 2008 Xavi Carrillo (www.mundodisea.com)
Last Modified: 06-26-2009
License: GPL
"""

usage = """
%prog [options]

  It Checks when a given string appeared for the last time on a log file
  It can be used against tomcat, apache error log and apache access file. Each has a different way to store the timestamp,
  therefore the type of log has to be given in the command line.

Use --help to view options
"""

import sys, datetime, time
from datetime import timedelta
from optparse import OptionParser

def string2datetime(datestring, timestamp):
  """
  converts a string into a datetime object (in the given "timestamp" format, which has to have exactly 6 elements: [0-5])
  returns datetime
  """
  try: return datetime.datetime(*time.strptime(datestring, timestamp)[0:5])
  except: print sys.exc_info()[1]

def GetTimeStampFromLogs(lastLine,logtype):
  if logtype == "tomcat":
    # 2008-07-25 12:29:07,145 DEBUG [work-8] [services.processing.UploadXmlProcessorServiceImpl] - Renaming file....
    TimeStampFromLogs = lastLine.split(",")[0]
    TimeStampFormat = "%Y-%m-%d %H:%M:%S"  #[Year-month-day Hour:Minute:Second]
            
  if logtype == "apache-error":
    # [Thu Aug 21 14:33:02 2008] [error] proxy: client 192.168.160.247 given Content-Length did not match number of body bytes read
    TimeStampFromLogs = lastLine.split()[1:5]
    Day = TimeStampFromLogs[1]
    Month = TimeStampFromLogs[0]
    Year = TimeStampFromLogs[3].replace(']','')
    Date = TimeStampFromLogs[2]
    TimeStampFromLogs = ' '.join([Day,Month,Year,Date])
    TimeStampFormat = '%d %b %Y %H:%M:%S'
            
  if logtype == "apache-access":
    #192.168.160.247 - - [21/Aug/2008:14:44:59 +0100] "GET /uk/ugc-upload HTTP/1.1" 200 39 "-" "Mozilla/5.0 ...
    TimeStampFromLogs = lastLine.split()[3].replace('[','')
    TimeStampFormat = "%d/%b/%Y:%H:%M:%S"  #[day/month name/year:Hour:Minute:Second]
        
  if logtype == "F5":
    #Sep 21 17:22:20 domainltm01 system_check: 010d0005:3: Chassis fan 101: status (0) is bad.
    Year = datetime.datetime.today().year
    TimeStampFromLogs = lastLine.split()[0:3]
    TimeStampFromLogs = ' '.join(TimeStampFromLogs)+' '+str(Year)
    TimeStampFormat = "%b %d %H:%M:%S %Y"  #[monthname day Hour:Minute:Second Year]: Sep 25 16:22:20 2008

  return TimeStampFromLogs, TimeStampFormat

def exit(output,exitstatus,perfdata,minutes):
  if perfdata == True:
    print '%s|minutes=%d' %(output,minutes)
  else:
    print '%s' %(output)
  sys.exit (exitstatus)                
                
def main():
  # Default values
  minutes = 0
  found = False    

  parser = OptionParser(usage, version=__version__)
  parser.add_option("-L", "--licence", action="store_true", default=False, help="Display license information and exit")
  parser.add_option("-l", action="store", dest="logfile", type="string", help="full path of the log file")
  parser.add_option("-s", action="store", dest="string", type="string", help="String to look for, between ''. For example: 'readonly filesystem'")
  #parser.add_option("-n", action="store", dest="nameOfService", type="string", help="Name of the Service. For example 'ReadOnly FileSystem Error'.")
  parser.add_option("-t", "--logtype",  action="store", dest="logtype", type="string", default="tomcat", help="Type of log. \n It can be either tomcat, F5, apache-error or apache-access.")
  parser.add_option("-W", action="store", dest="words", type="int", help="Number of words the line should have (if different, critical)")
  parser.add_option("-w", action="store", dest="warning", type="int", default=None, help="warning threshold, in minutes")
  parser.add_option("-c", action="store", dest="critical", type="int", help="critical threshold, in minutes")
  parser.add_option("-r", "--reverse", action="store_true", default=False, help="Reverse. Returns CRITICAL if the message IS there within the given time.")
  parser.add_option("-p", "--perfdata", action="store_true", default=False, help="Outputs nagios 'performance data'")
  parser.add_option("-d", "--delta", action="store", dest="delta", type="string", default="+0", help="Delta time: to add or substract to the system date, in minutes. Usefull if the logs timezone doesn't match the system timezone. For example: -d +10 or -d -10 will go 10 minutes to the future or past")
                      
  (options, args) = parser.parse_args()

  if options.licence:
    print '\n'
    print __title__, __version__
    print __licence__
    sys.exit(0)
  else:
    if not options.logfile:
      parser.error("Logfile is mandatory")
    if not options.string:
      parser.error("String is mandatory")
    if not options.warning:
      parser.error("Warning value is mandatory")
    #if not options.critical:
    #    parser.error("Critical value is mandatory")

  if options.critical:
    if options.warning > options.critical:
      parser.error("critical has to be greater than warning")
    if options.logtype not in ['tomcat','apache-access','apache-error','F5']:
      parser.error("Logtype has to be either 'tomcat','apache-access','apache-error'")

  #Let's see if the string is there
  try: logfile = open(options.logfile, 'r')
  except IOError: 
    output = 'CRITICAL : Cannot open '+options.logfile
    exitstatus = 2
    perfdata = False
    exit(output,exitstatus,options.perfdata,minutes)
  else:
    for line in logfile:
      if options.string in line:
        found = True
        lastLine = line
    logfile.close()

  if found:
    delta = timedelta(minutes=int(options.delta))
    now = datetime.datetime.today() + delta
    TimeStampFromLogs,TimeStampFormat =  GetTimeStampFromLogs(lastLine,options.logtype)
    LastLineTimeStamp = string2datetime(TimeStampFromLogs,TimeStampFormat)
    TimeFromLastEntry = now - LastLineTimeStamp
    days = TimeFromLastEntry.days
    minutes = TimeFromLastEntry.seconds / 60
    numberOfWords = len(lastLine.split())

    # If the difference of times is negative, the timezones don't match. We warn the user only if he hasn't set up the delta option (which is +0 by default)
    if days < 0 and options.delta == "+0":
      exitstatus = 1
      output = "WARNING: Timezones don't match! logs are in the future. If this is ok, please travel in time using the --delta option"
      exit(output,exitstatus,options.perfdata,minutes)

    if days > 0:
      minutes = minutes + days*3600

    if options.reverse:
      if not options.critical:
        if minutes < options.warning:
          exitstatus = 1
          statusmsg = "WARNING"
        if minutes >= options.warning:
          exitstatus = 0
          statusmsg = "OK"
        else:
          if minutes < options.critical:
            exitstatus = 2
            statusmsg = "CRITICAL"
          if minutes >= options.critical:
            exitstatus = 0
            statusmsg = "OK"
    else:
      if minutes < options.warning:
        exitstatus = 0
        statusmsg = "OK"
      if minutes >= options.warning:
        exitstatus = 1
        statusmsg = "WARNING"
      if minutes >= options.critical:
        exitstatus = 2
        statusmsg = "CRITICAL"

    output = statusmsg+": "+str(minutes)+" minutes from the last entry of '"+options.string+"':" + lastLine

    if options.words:
      if numberOfWords != options.words:
        exitstatus = 2
        statusmsg = "CRITICAL"
        output = statusmsg + ": The string has " + str(options.words) + " words"
      else:
        exitstatus = 0
        statusmsg = "OK"
        output = statusmsg + ": The string has "+str(options.words)+" words"
  else:
    if options.reverse:
      # If reverse is enabled, not finding the string is a good thing
      exitstatus = 0
      statusmsg = "OK"
    else:
      exitstatus = 3
      statusmsg = "UNKNOWN"
      output = statusmsg+': The string was not found'

  exit(output,exitstatus,options.perfdata,minutes)

if __name__ == "__main__":
  main()
