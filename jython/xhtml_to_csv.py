#!/usr/bin/python

import string
import sys
import pdb
import urllib
import xml.etree.ElementTree as ET

#pdb.set_trace()

URL = "http://dashboard/cgi-bin/gpfs"

tree_ = ET.parse(urllib.urlopen(URL))
root_ = tree_.getroot()
body_ =  root_.find('{http://www.w3.org/1999/xhtml}body')
table_ = body_.find('{http://www.w3.org/1999/xhtml}table')
tr_ = table_.findall('{http://www.w3.org/1999/xhtml}tr')

for i_ in range(len(tr_)):
  if i_ > 0 :
    td_ = tr_[i_].findall('{http://www.w3.org/1999/xhtml}td')
  else :
    td_ = tr_[i_].findall('{http://www.w3.org/1999/xhtml}th')

  row_ = []
  for o_ in td_ :
    row_.append(o_.text if o_.text else '')

  if i_ == 0 :
    print ",".join(row_)

  if i_ > 0 :
    if (row_[3] != 'FILESET' and int(row_[7]) > 80) or row_[3][0:2] == 'gx' or row_[3][0:3] == 'z22' :
      print ",".join(row_)

sys.exit(0)
