#!/usr/bin/env python
# -*- coding: utf-8 -*-
#

"""
Nagios plugin to check the free memory in the system.
"""

__title__ = "check_freemem"
__version__ = "0.2"
__author__= "Xavi Carrillo"
__email__= "xcarrillo at domain dot com"

import sys
from optparse import OptionParser

def main():
        usage = "usage: %prog [options]\n \
                 Nagios plugin to check the free memory in the system. \n \
                 Use --help to view options"
        parser = OptionParser(usage, version=__version__)
        parser.add_option("-w", "--warning", action="store", dest="warning", type="string",
                          help="Warning threadshold, percent")
        parser.add_option("-c", "--critical", action="store", dest="critical", type="string",
                          help="Critical threadshold, percent")

        (options, args) = parser.parse_args()

        if not options.warning:
                parser.error("warning is mandatory")
        if not options.critical:
                parser.error("critical is mandatory")

        warning = int(options.warning)
        critical = int(options.critical)
        if warning < critical:
                parser.error("warning should be greater than critical")


        try:
                        f = open('/proc/meminfo', 'r')
        except IOError:
                        print 'cannot open /proc/meminfo'
        else:
                        FirstLine = f.read(25).split() # The first line is 25 bytes long. Two words in string format is returned. We convert that to 'list'.
                        MemTotal = int(FirstLine[1]) # We are interested in the second word (MemTotal value)
                        SecondLine = f.read(26).split() # The second one is 26 bytes long.
                        MemFree = int(SecondLine[1])
                        PerCent_MemFree = (MemFree * 100) / MemTotal

                        if PerCent_MemFree <= warning:
                                statusmessage = "WARNING"
                                exitstatus = 1
                        if PerCent_MemFree <= critical:
                                statusmessage = "CRITICAL"
                                exitstatus = 2
                        if PerCent_MemFree > warning:
                                statusmessage = "OK"
                                exitstatus = 0

                        print statusmessage,"-",PerCent_MemFree,"% of memory free"
                        sys.exit(exitstatus)
                        f.close()

if __name__ == "__main__":
        main()
