#!/usr/bin/python

import pdb
import sys
import xml.etree.ElementTree as ET

# Uncomment next line to drop into debugger
# pdb.set_trace()

#
# This python script is used to parse the Get List Response from Share Point
# returned from http://my_sp_server/my_sp_site/etl/_api/lists/getByTitle%28%27Servers%27%29/items
#
tree_ = ET.parse(sys.argv[1])
root_ = tree_.getroot()

printBanner_ = 0

for entry_ in root_.findall('{http://www.w3.org/2005/Atom}entry') :
    for content_ in entry_.findall('{http://www.w3.org/2005/Atom}content') :
        for properties_ in content_.findall('{http://schemas.microsoft.com/ado/2007/08/dataservices/metadata}properties') :
                if printBanner_ < 1 :
                        print "HOST&PRODUCT"
                        printBanner_ = 1
                title_ = properties_.find('{http://schemas.microsoft.com/ado/2007/08/dataservices}Title')
                product_ = properties_.find('{http://schemas.microsoft.com/ado/2007/08/dataservices}PRODUCT_NAME');
                print title_.text + "&" + product_.text
