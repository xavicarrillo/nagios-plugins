#!/usr/bin/env python
# -*- coding: utf-8 -*-
#

"""
Tests an SNG API console. Can be used as a Nagios check.
"""

__title__ = "check_SNG_API"
__version__ = "0.1"
__author__= "Xavi Carrillo"
__email__= "xcarrillo at domain dot com"

baseURL = "http://localhost:8080/sng-api-console-2.6.rc1/sng-api-console"
#baseURL = "http://nbg2-lglinkbook-beta-vip.gasp2.domain.com/sng-api-console/sng-api-console/sng"

SNG_auth_URL = baseURL + '/sng/auth'
SNS_auth_URL= baseURL + '/sns/auth'
friendsURL = baseURL + '/sns/friends'
minifeedURL = baseURL + '/sns/minifeed'

FB_Login = "ugcsnsdebug@gmail.com"
FB_Password = "whatever11"
TW_Login = "sng_domain"
TW_Password = "domain"
BB_Login = "orangeproxy"
BB_Password = "domain"
  

import libxml2, sys, pycurl, string
from xml.dom import minidom
from xml.dom import EMPTY_NAMESPACE
from optparse import OptionParser

class Test:
    def __init__(self):
        self.contents = ''

    def body_callback(self, buf):
        self.contents = self.contents + buf

def exit(message, exitstatus):
    print message
    sys.exit(exitstatus)

def getValueFromXMLtag(xml,tag, errorMessage, exitErrorCode):  
    try:
        doc = libxml2.parseDoc(xml)
        child = doc.children.children
        while child is not None:
            if child.name == tag:
                return child.content
            child = child.next
        xml.freeDoc()
    except Exception, error:
        exit("%s: %s" %(errorMessage, error), exitErrorCode)

#def run(command):
#    try:    
#        return subprocess.Popen(command, shell=True, stdout=subprocess.PIPE).stdout
#    except Exception, error:
#        exit("UNKNOWN: %s" %(error), 3)

def httpRequest(URL, fields, verbose):
    # remote URI
    # Post fields. Use '' if you want a GET instead of a POST.
    # verbosity. 1=yes
    
    page = Test() # we need the page.body_callback to capture the output. Weird, I know.
    curl = pycurl.Curl()
    curl.setopt(pycurl.URL, URL)
    curl.setopt(curl.POSTFIELDS,fields)
    if fields == '':
        curl.setopt(pycurl.POST,0) # If "fields" is empty, it's a GET
    else:
        curl.setopt(pycurl.POST,1) # Otherwise it's a POST.
    #curl.setopt(pycurl.HEADER,1)
    curl.setopt(curl.CONNECTTIMEOUT, 10)
    curl.setopt(curl.TIMEOUT, 25) 
    curl.setopt(curl.WRITEFUNCTION, page.body_callback)
    if verbose == 1:
            curl.setopt(pycurl.VERBOSE, 1)
    try:
        curl.perform()
    except Exception, error:
        exit("%s: %s" %("CRITICAL: Couldn't connect to the website - ", error), 2)
    else:
        curl.close()
        return page.contents
                        
def getText(nodelist):
    rc = ""
    for node in nodelist:
        if node.nodeType == node.TEXT_NODE:
            rc = rc + node.data
    return rc

def getAtomTagValue(document, ROOT, TAG):
    valuesList = ''
    num = 0
    try:
        dom = minidom.parseString(document)
        dom.normalize()
        entries = dom.getElementsByTagName(ROOT)

        for entry in entries:
            names = entry.getElementsByTagName(TAG)
            for name in names:
                #getText(name.childNodes)
                num = num +1
                valuesList = valuesList + '\n\t' + getText(name.childNodes)
    except Exception, error:
        exit("%s: %s" %("CRITICAL: Couldn't parse Atom feed - ", error), 2)
    else:
        return num, valuesList

def loginSNG(MSISDN):        
    fields = 'userUidHeaderName=x-domain-user-uid&userUid=%s&showXml=1' %(MSISDN)
    response = httpRequest(SNG_auth_URL, fields, 0)
    token = getValueFromXMLtag(response, "token", "CRITICAL: Couldn't log in on SNG - ", 2)
    return token

def loginSNS(login, password, snsUid, token):
    errorMessage = "CRITICAL: Couldn't log in on %s - " %(snsUid)
    fields = 'username=%s&password=%s&snsUid=%s&sessionToken=%s' %(login, password, snsUid, token)
    response = httpRequest(SNS_auth_URL, fields, 0)
    uid = getValueFromXMLtag(response,"uid", errorMessage, 2)
    return uid

def getFriends(snsUid, token, uid):
    URL = friendsURL+'?snsUid=%s&sessionToken=%s&snsUserUid=%s&pageNum=1&pageSize=10' %(snsUid, token, uid)
    response = httpRequest(URL, '', 0)
    try:
        num, friends = getAtomTagValue(response, "entry", "title")
    except Exception, error:
        exit("%s: %s" %("CRITICAL = Couldn't get the list of friends - ", error), 2)
    else:
        return num, friends

def getMinifeed(snsUid, token, uid):
    URL = minifeedURL+'?snsUid=%s&sessionToken=%s&snsUserUid=%s&pageNum=1&pageSize=10&rangeFrom=&rangeTo=&ifModifiedSince=' %(snsUid, token, uid)
    response = httpRequest(URL, '', 0)
    try:
        num, friends = getAtomTagValue(response, "entry", "title")
        friends = string.replace(friends, "Minifeed category: ","")
    except Exception, error:
        exit("%s: %s" %("CRITICAL = Couldn't get the list of minifeeds - ", error), 2)
    else:
        return num, friends

def performAction(SNS, token, uid, action):
    if action == "friends" or action == "all":
        num, friends = getFriends(SNS, token, uid)
        print "%s %s Friends: (limited to 10) %s" %(num, SNS, friends)
        
    if action == "minifeed" or action == "all":
        num, feeds = getMinifeed(SNS, token, uid)
        print "%s %s feeds: (limited to 10) %s" %(num, SNS, feeds)
            
def main():

    usage = "Usage: %prog [options]\n \n \
    With a given MSISDN it logs in an SNG server and performs actions against one or several Social Networks \n \n \
    Use --help to view options"
    parser = OptionParser(usage, version=__version__)
    parser.add_option("-m", "--msisdn", action="store", dest="MSISDN", type="string",
                      help="Mobile phone number to register on a SNG server as a client.")
    parser.add_option("-s", "--sns", action="store", dest="SNS", type="string",
                      help="Social Network Site to perform actions to. 'TW' for Twitter, 'FB' for Facebook, 'BB' for Bebo, 'all' to check all available SNS.")
    parser.add_option("-a", "--action", action="store", dest="action", type="string",
                      help="Action to perform in the SNS: 'friends', 'minifeed' or 'all'")
    
    (options, args) = parser.parse_args()

    if not options.MSISDN:
        parser.error("MSISDN is mandatory")
    if not options.SNS:
        parser.error("SNS is mandatory")
    if options.SNS not in ['FB','TW','BB','all']:    
        parser.error("SNS can be either 'TW', 'FB', 'BB' or 'all'")
    if not options.action:
        parser.error("'action' is mandatory")
    if options.action not in ['friends', 'minifeed', 'all']:
        parser.error("action must be 'friends' or 'minifeed'")

    if options.SNS == 'FB':
        login = FB_Login
        password = FB_Password
    elif options.SNS == 'BB':
        login = BB_Login
        password = BB_Password
    elif options.SNS == 'TW':
        login = TW_Login
        password = TW_Password
        
    token = loginSNG(options.MSISDN)
    
    if options.SNS == 'all':
        uid = loginSNS(FB_Login, FB_Password, "FB", token)
        performAction("FB", token, uid, options.action)
        
        uid = loginSNS(BB_Login, BB_Password, "BB", token)
        performAction("BB", token, uid, options.action)
        
        uid = loginSNS(TW_Login, TW_Password, "TW", token)
        performAction("TW", token, uid, options.action)  
    else:            
        uid = loginSNS(login, password, options.SNS, token)
        performAction(options.SNS, token, uid, options.action)
    
    exit("\n OK - All tests passed successfully", 0)


if __name__ == "__main__":
    main()
