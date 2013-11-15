#!/usr/bin/python2.4
# -*- coding: utf-8 -*-
#

"""
Checks the stats of a memcached server. Can be used as a Nagios script.
"""

__title__ = "check_memcached"
__version__ = "0.1"
__changelog__ = ""
__author__= "Xavi Carrillo"
__email__= "xcarrillo at domain dot com"


from optparse import OptionParser
import sys, telnetlib
#import pprint
import exceptions
e = exceptions.Exception


    
# the "total_connections" parameter represents the historic number of connection that have been made to the server
# "curr_connections" is the number of live sessions

def getValue(variable, input):
    return input.split(variable)[1].split("STAT")[0].strip()

def percentage(first, second):
    return first*100/second

def exit(message, exitstatus):
    print message
    sys.exit(exitstatus)

def evaluate(value, warning, critical, message, inverse):
    
    perfdata = " | '%s'=%s" %(message, value)
    info = message + " is " + str(value) + "%" + perfdata
    
    if inverse:
        if value <= critical:
            message = "CRITICAL: " + info
            exit(message,2)
        if value <= warning:
            message = "WARNING: " + info
            exit(message,1)
        else:
            message = "OK: " + info
            exit(message,0)        
    else:
        if value >= critical:
            message = "CRITICAL: " + info
            exit(message,2)
        if value >= warning:
            message = "WARNING: " + info
            exit(message,1)
        else:
            message = "OK: " + info
            exit(message,0)

def main():
    
    usage = "\n%prog [options]\nUse --help to view options"
    parser = OptionParser(usage, version=__version__)
    parser.add_option("--host", action="store", dest="host", type="string", default="localhost", help="memcached host, default localhost")
    parser.add_option("-p", "--port", action="store", dest="port", type="int", default="11211", help="memcached port, default 11211") 
    parser.add_option("--check", action="store", dest="check", type="string",
                      help="name of the check: size_ratio (cache size ratio) or hit_ratio (cache hit ratio)") 
    parser.add_option("--stats", action="store_true", dest="stats", help="output stats and quit") 
    parser.add_option("-w", "--warning", action="store", dest="warning", type="int", help="warning threashold. A percentage")
    parser.add_option("-c", "--critical", action="store", dest="critical", type="int", help="critical threashold. A percentage")
    (options, args) = parser.parse_args()

    if options.warning > options.critical and options.check == "size_ratio":
        parser.error("warning has to be smaller than critical if check is size_ratio")
    if options.warning < options.critical and options.check == "hit_ratio":
        parser.error("warning has to be greater than critical if check is hit_ratio")
    if options.check:
        if options.check not in ['size_ratio','hit_ratio']:
            parser.error("check must be either 'size_ratio' or 'hit_ratio'")
        
    try:
        session = telnetlib.Telnet(options.host, options.port)
    except Exception, error:
        exit("CRITICAL: Couldn't connect to the host", 2)
    
    session.write("stats\n")
    output = session.read_until("END", 5) # 5 is the timeout
    output = output.replace("END","")
    session.write("quit\n")

    if options.stats:
        # Used for cacti graphs
        variables = [ "total_items", "get_hits", "uptime", "cmd_get", "time", "bytes", "curr_connections", "connection_structures", "bytes_written", "limit_maxbytes", "cmd_set", "curr_items", "rusage_user", "get_misses", "rusage_system", "bytes_read", "total_connections"]
        for variable in variables:
            # we remove the last 4 decimals because the Cacti template only wants 2 decimals
            value = getValue(variable,output)
            if "." in value:
                value = getValue(variable,output)[:-4]
            print variable + ":" + value,
        sys.exit(0)
        
    
    try:
        if options.check == "size_ratio":
            value1 = int(getValue("bytes", output))
            value2 = int(getValue("limit_maxbytes", output))
        else:
            value1 = int(getValue("get_hits", output))
            value2 = int(getValue("cmd_get", output))
    except Exception, error:
        message = "CRITICAL: Couldn't get the stats from memcached: %s" %(error)
        exit(message, 2)
                      
    # we don't want an integer division by zero ;)
    if value2 == 0:
        result = 0
    else:
        result = percentage(value1, value2)

    if options.check == "size_ratio":
        evaluate(result, options.warning, options.critical, options.check, False) # Last parameter means reverse
    else:
        evaluate(result, options.warning, options.critical, options.check, True) # In this case, warning has te be greater
        
if __name__ == "__main__":
    main()

