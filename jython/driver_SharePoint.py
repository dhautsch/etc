#!/export/apps/anaconda3/bin/python

import os
import sys

sys.path.insert(0, os.environ['HOME'] + '/MyPythonModules')

import pdb
import re
import time
from pprint import pprint as pp

import SharePoint

def getConfig(cfg = None):
    import Utils

    cfg_ = cfg if cfg else os.environ['HOME'] + '/config.properties'
    ret_ = Utils.getProps(cfg_, { 'SP_CONN' : 'sharepoint_conn'
                                  , 'SP_URL' : 'sharepoint.url'
                                  , 'PROXY' : 'proxy.url' } ) 

    if 'SP_CONN' not in ret_ or 'SP_URL' not in ret_:
        print("Cannot initialize from " + CONFIG)
        sys.exit(1)
    else:
        onCloud_ = re.search(r'sharepoint\.com', ret_['SP_URL'])
        conn_ = None

        for s_ in Utils.qx(os.environ['HOME'] + '/bin/decrypt ' + ret_['SP_CONN']):
            m_ = re.match('.+\@.+', s_.decode("utf-8"))
            if m_:
                a_ = s_.decode("utf-8").split('@')
                user_ = a_[0]
                b_ = user_.split('\\')
                a_.insert(0, b_[0])
                if onCloud_:
                    a_[1] = b_[1] + '@' + b_[0].lower() + '.com'

                conn_ = a_
                
                break

        if conn_:
            ret_['SP_CONN'] = conn_
            if onCloud_:
                os.environ['HTTPS_PROXY'] = ret_['PROXY']
        else:
            print("Connection string looks odd")
            sys.exit(1)

    return ret_

PROPS = os.environ['HOME'] + '/MSG/localsp-config.properties'
PROPS = os.environ['HOME'] + '/MSG/cloudsp-config.properties'

PROPS = getConfig(PROPS)
os.environ['HTTPS_PROXY'] = PROPS['PROXY']

pdb.set_trace()

SP = SharePoint.SharePointList(  PROPS['SP_CONN'][1]
                               , PROPS['SP_CONN'][2]
                               , PROPS['SP_URL'], 'Bogus' )

listMeta_ = SP.getMeta()
pp(listMeta_)

pdb.set_trace()

CNT = 0

ret_ = SP.getItems()
if ret_ is not None:
    for item_ in ret_:
        print('First  fetch({}) {}'.format(item_['ID'], item_['Title']))
        CNT += 1

print("COUNT={}".format(CNT))
pdb.set_trace()

CNT = 0

ret_ = SP.getItems({'$top': listMeta_['ItemCount']})
if ret_ is not None:
    for item_ in ret_:
        print('Second  fetch({}) {}'.format(item_['ID'], item_['Title']))
        CNT += 1

print("COUNT={}".format(CNT))
pdb.set_trace()

CNT = 0

ret_ = SP.getItems({'$top': 5})
if ret_ is not None:
    for item_ in ret_:
        print('third  fetch({}) {}'.format(item_['ID'], item_['Title']))
        CNT += 1

print("COUNT={}".format(CNT))
pdb.set_trace()

ret_ = SP.append({ 'Title': 'New_Item ' + time.asctime( time.localtime(time.time())) })
pp(ret_)

pdb.set_trace()

ret_ = SP.merge( { 'Title': 'Updated ' + time.asctime( time.localtime(time.time())) }, ret_['ID'])
pp(ret_)

pdb.set_trace()

ret_ = SP.getItem(ret_['ID'])
pp(ret_)

pdb.set_trace()

ret_ = SP.remove(ret_['ID'])
pp(ret_)
