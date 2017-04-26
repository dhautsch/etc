#!/usr/bin/python3.5

from pprint import pprint as pp
from xml.etree import ElementTree
import pdb
import requests
from requests_ntlm import HttpNtlmAuth
import sys
import os

def qx(cmd):
    import subprocess

    pipe_ = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True, bufsize=-1, close_fds=True)
    try:
        for l_ in pipe_.stdout:
            s_ = l_.rstrip()
            if len(s_) > 0: yield(s_)
    finally:
        pipe_.stdout.close()

#pdb.set_trace()

BLOWFISH_CONN = 'BLOWFISH_STRING'
HTTP_AUTH = None

SESSION = requests.Session()

for s_ in qx(os.environ['HOME'] + '/bin/decrypt ' + BLOWFISH_CONN):
    a_ = s_.decode("utf-8").split('@')
    HTTP_AUTH = HttpNtlmAuth(a_[0], a_[1], SESSION)

if HTTP_AUTH is None:
    print("HTTP_AUTH is None")
    sys.exit(1)

def getUrls(url, sp_list = None):
    ret_ = dict()
    ret_['url'] = url
    ret_['digest'] = '{}/_api/contextinfo'.format( url )
    if sp_list is not None:
        ret_['sp_list'] = '{}/_api/lists/getByTitle%28%27{}%27%29'.format( url, sp_list)
        ret_['sp_list_items'] = ret_['sp_list'] + '/items'

    return ret_

URLS = getUrls('SP_WEB_URL', 'SP_LIST')

HEADERS = { 'accept' : 'application/json;odata=verbose' }

response = SESSION.post(URLS['digest'], data = {}, auth = HTTP_AUTH, headers = HEADERS)
if response.status_code == 200:
    OBJ = response.json()
    for s_ in [ 'SiteFullUrl', 'WebFullUrl' , 'FormDigestValue' ]:
        print("{}='{}'".format( s_, OBJ['d']['GetContextWebInformation'][s_]))

response = SESSION.get(URLS['sp_list'], auth = HTTP_AUTH, headers = HEADERS)
if response.status_code == 200:
    OBJ = response.json()
    for s_ in [ 'Title', 'LastItemDeletedDate' , 'LastItemModifiedDate', 'ListItemEntityTypeFullName', 'ItemCount' ]:
        print("{}='{}'".format( s_, OBJ['d'][s_]))

response = SESSION.get(URLS['sp_list_items'], auth = HTTP_AUTH, headers = HEADERS, params = {'$top': OBJ['d']['ItemCount']})
if response.status_code == 200:
    OBJ = response.json()
    pp(OBJ['d']['results'])

sys.exit(0)
