#!/usr/bin/env python
# -*- coding: utf-8 -*-
#

"""
Checks if kewego trailers are available to domain. 
It does so by asking kewego's API for a token within an XML file which is used to get a FLV file.
"""

__title__ = "check_kewego"
__version__ = "0.1"
__author__= "Xavi Carrillo"
__email__= "xcarrillo at domain dot com"

import urllib, libxml2, sys

def showMethods(objecte):
    # needs import sys    
    contains = dir(objecte)
    for func in contains:
        return func

def main():
    # We get the token
    getToken = urllib.urlopen('http://api.kewego.com/app/getToken/?appKey=75affcd3efe9071a0184877f96c897fe').read()
    xmlFile = libxml2.parseDoc(getToken)
    root = xmlFile.children
    child = root.children
    counter = 1
    while counter < 3:
	token=child.content
	child = child.next
        counter = counter + 1
    xmlFile.freeDoc()
    
    # We check the token
    url = 'http://api.kewego.com/app/checkToken/?appToken='.__add__(token)  
    checkToken = urllib.urlopen(url).read()
    xmlFile = libxml2.parseDoc(checkToken)
    response = xmlFile.content.strip()
    xmlFile.freeDoc()
    
    if response == 'Invalid Token':
        output = 'kewego API check is CRITICAL: Invalid Token'
        exitstatus = 2
    else:
        # Response is 'true'
        output = 'kewego API check is OK: Token was accepted'
        exitstatus = 0

    print '%s' %(output)
    sys.exit (exitstatus)
    
        
if __name__ == "__main__":
        main()




