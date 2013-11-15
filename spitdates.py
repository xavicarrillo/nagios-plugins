#!/usr/bin/env python
# -*- coding: utf-8 -*-
#

"""
spits pairs of dates in ISO format, taking an initial and final date, and the period between them.
"""

__title__ = "datespit"
__version__ = "0.4"
__author__= "Xavi Carrillo"
__email__= "xcarrillo at domain dot com"

import sys,datetime,time,re
from optparse import OptionParser

def string2datetime(datestring):
        """
        converts a given string (in the format "2008-12-31") to a datetime object
        returns datetime
        """
        try:
                return datetime.datetime(*time.strptime(datestring, "%Y-%m-%d")[0:5])
        except:
                print 'not a date in ISO format. Date should be in YYYY-MM-DD'

def datetime2string(date_object):
        """
        converts a given datetime object to a string (in the format "2008-12-31")
        returns string
        """
        try:
                return date_object.strftime("%Y-%m-%d")
        except:
                print 'Not in the expected format.'

def check_date_format(date_string):
        """
        Checks if the given string is in the format YYYY-MM-DD
        Takes String
        Returns Booleann
        """
        if re.match("^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}$",date_string):
                return True
        else:
                return False

def one_month_less(d):
        """
        Takes datetime
        Returns datetime, a month before the given one
        """
        year, month= d.year, d.month
        if month == 1:
                year-= 1; month= 12
        else:
                month-= 1
        try:
                return d.replace(year=year, month=month)
        except ValueError:
                return d.replace(day=1) - datetime.timedelta(1)

def main():

        one_day = datetime.timedelta(days=1)
        one_week = datetime.timedelta(weeks=1)
        today = datetime.datetime.today()

        usage = "usage: %prog [options]\n \
                 Spits to stdout pairs of dates in ISO format, taking an initial and final date, and the period between them. \n \
                 Examples: \n \
                 Use --help to view options"
        parser = OptionParser(usage, version=__version__)
        parser.add_option("-f", "--firstdate", action="store", dest="firstdate", type="string",
                          help="Begining date, in ISO format. IE: 2007-10-20. Can take also these values: yesterday,oneweekless,onemonthless")
        parser.add_option("-l", "--lastdate", action="store", dest="lastdate", type="string",
                          help="End date, in ISO format. Can take also these values: 'today', 'yesterday'")
        parser.add_option("-p", "--period", action="store", dest="period", type="string", default="daily",
                          help="Period between dates. Can be 'daily','weekly'")

        (options, args) = parser.parse_args()

        ### Argument parsing ###
        if not options.firstdate:
                parser.error("firstdate is mandatory")
        if not options.lastdate:
                parser.error("lastdate is mandatory")

        if options.lastdate not in ['today','yesterday']:
                if not check_date_format(options.lastdate):
                        parser.error("Last date has to be either 'today' or 'yesterday' or a date in ISO format: YYYY-MM-DD")
                else:
                        lastdate = string2datetime(options.lastdate)
        else:
                lastdate = today
        if options.lastdate == "yesterday":
                lastdate = today - one_day

        if options.firstdate not in ['yesterday','oneweekless','onemonthless']:
                if not check_date_format(options.firstdate):
                        parser.error("First date has to be either 'yesterday','oneweekless' or 'onemonthless' or a date in ISO format: YYYY-MM-DD")
                else:
                        firstdate = string2datetime(options.firstdate)
        else:
                if options.firstdate == "yesterday":
                        firstdate = today - one_day
                elif options.firstdate == "oneweekless":
                        firstdate = lastdate - one_week
                elif options.firstdate == "onemonthless":
                        firstdate = one_month_less(lastdate)

        if options.period not in ['daily','weekly']:
                parser.error("Period has to be either 'daily' or 'weekly'")
        else:
                if options.period == "daily":
                        difference = one_day
                elif options.period == "weekly":
                        difference = one_week
        ### End of Argument parsing ###

        while firstdate < lastdate :
                begining = datetime2string(firstdate)
                firstdate = firstdate + difference
                end = datetime2string(firstdate)
                if firstdate > lastdate:
                        end = datetime2string(lastdate)
                print begining, end

if __name__ == "__main__":
        main()

