"""SPList class to interact with SharePoint

from sharepoint import SPList

SP_LIST = SPList('domain\\scott', 'tiger', 'http://sharepoint', 'Bogus_List')

ret_ = SP_LIST.addItem({'ELAPSED_SECS': 0, 'EXTRACT_CNT': 0, 'STATUS': 'RUNNING', 'Title': 'nemo'})

ret_ = SP_LIST.updateItem(ret_['ID'], {'ELAPSED_SECS': 20, 'EXTRACT_CNT': 200, 'STATUS': 'DONE'})

for o_ in SP_LIST.getItems('$filter', "Title eq 'nemo'"):
    pass
"""

import requests
from requests_ntlm import HttpNtlmAuth
import json

class SPList:
    """Class to interact with SharePoint"""
    
    _httpAuth = None
    _session = None
    _urls = None
    _headers = { 'accept' : 'application/json;odata=verbose' }

    def __del__(self):
        pass
#        if self._session is not None: self._session.close()

    def __init__(self, spUser, spPass, spUrl, spList):
        """Construct object to interact with SharePoint.

        :Parameter spUser: domain\\userid string.
        :Type spUser: str

        :Parameter spPass: password string.
        :Type spPass: str

        :Parameter spUrl: URL to SharePoint site.
        :Type spUrl: str

        :Parameter spList: the name of the SharePoint List
        :Type spList: str

        :Return: On success a digest string. On failure, None.
        """
        self._session = requests.Session()

        if self._session:
            self._httpAuth = HttpNtlmAuth(spUser, spPass, self._session)

        if self._httpAuth is not None:
            self._urls = dict()
            self._urls['url'] = spUrl
            self._urls['digest'] = '{}/_api/contextinfo'.format( spUrl )
            self._urls['sp_list'] = '{}/_api/lists/getByTitle%28%27{}%27%29'.format( spUrl, spList)
            self._urls['sp_list_items'] = self._urls['sp_list'] + '/items'

    def getDigest(self):
        """Get digest from SharePoint.

        :Return: On success a digest string. On failure, None.
        """
        ret_ = None

        response_ = self._session.post(self._urls['digest']
                                       , data = {}
                                       , auth = self._httpAuth
                                       , headers = self._headers)
        if response_.status_code == 200:
            obj_ = response_.json()['d']['GetContextWebInformation'] 
            ret_ = obj_['FormDigestValue']

        return ret_

    def getMeta(self):
        """Get SharePoint list meta data.

        :Return: On success an object containing Title, LastItemDeletedDate, LastItemModifiedDate, ListItemEntityTypeFullName, ItemCount. On failure, None.
        """
        ret_ = None

        response_ = self._session.get(self._urls['sp_list']
                                      , auth = self._httpAuth
                                      , headers = self._headers)
        if response_.status_code == 200:
            ret_ = dict()
            obj_ = response_.json()

            for s_ in [ 'Title', 'LastItemDeletedDate' , 'LastItemModifiedDate', 'ListItemEntityTypeFullName', 'ItemCount' ]:
                ret_[s_] = obj_['d'][s_]

        return ret_

    def getItems(self, spFilter = None, spFilterValue = None):
        """Get SharePoint list items.

        :Parameter spFilter: SharePoint filter.
        :Type spFilter: str

        :Parameter spFilterValue: SharePoint filter value.
        :Type spFilterValue: str

        :Return: On success list of objects from SharePoint. On failure, empty list.
        """
        ret_ = []
        
        if spFilter is not None:
            if spFilterValue is not None:
                response_ = self._session.get(self._urls['sp_list_items']
                                             , auth = self._httpAuth
                                             , headers = self._headers, params = {spFilter: spFilterValue})
                if response_.status_code == 200:
                    ret_ = response_.json()['d']['results']
                else:
                    pass
            else:
                pass
        else:
            response_ = self._session.get(self._urls['sp_list_items']
                                          , auth = self._httpAuth
                                          , headers = self._headers)
            if response_.status_code == 200:
                ret_ = response_.json()['d']['results']
            else:
                pass

        return ret_

    def addItem(self, data):
        """Add a SharePoint list item.

        :Parameter data: Dictionary of columns to add in SharePoint list item.
        :Type data: dict

        :Return: On success response object from SharePoint. On failure, None.
        """
        ret_ = None
        
        if data is not None and isinstance(data, dict):
            headers_ = { 'accept' : 'application/json;odata=verbose'
                         , 'content-type' : 'application/json;odata=verbose'
                         , 'X-RequestDigest' : self.getDigest()
                         , 'IF-MATCH' : '*' }
            data_ = { '__metadata': { 'type': self.getMeta()['ListItemEntityTypeFullName'] }}


            for k_ in data:
                data_[k_] = data[k_]

            #
            # request.post is turning the data object into get query params which is not
            # what sharepoint is expecting. I found this out by using
            #   req = Request('POST', url, data=data, headers=headers)
            #   prepped = req.prepare()
            # so this is why I am using json.dumps - don@hautsch.com

            data_ =  json.dumps(data_)

            response_ = self._session.post(self._urls['sp_list_items']
                                           , data = data_
                                           , auth = self._httpAuth
                                           , headers = headers_)
            if int(response_.status_code/100) == 2:
                ret_ = response_.json()['d']

        return ret_

    def updateItem(self, spID, data):
        """Update a SharePoint list item.

        :Parameter spID: The SharePoint list item ID.
        :Type spID: int

        :Parameter data: Dictionary of columns to update in SharePoint list item.
        :Type data: dict

        :Return: On success contents of data dict and with a new key/value (ID : spID). On failure, None.
        """

        ret_ = None
        
        if spID is not None and data is not None and isinstance(data, dict):
            headers_ = { 'accept' : 'application/json;odata=verbose'
                         , 'content-type' : 'application/json;odata=verbose'
                         , 'X-RequestDigest' : self.getDigest()
                         , 'IF-MATCH' : '*' }
            data_ = { '__metadata': { 'type': self.getMeta()['ListItemEntityTypeFullName'] }}


            for k_ in data:
                data_[k_] = data[k_]

#            pdb.set_trace()

            #
            # request.post is turning the data object into get query params which is not
            # what sharepoint is expecting. I found this out by using
            #   req = Request('POST', url, data=data, headers=headers)
            #   prepped = req.prepare()
            # so this is why I am using json.dumps - don@hautsch.com

            data_ =  json.dumps(data_)

            response_ = self._session.request('MERGE', self._urls['sp_list_items'] + '({})'.format(spID)
                                           , data = data_
                                           , auth = self._httpAuth
                                           , headers = headers_)
            if int(response_.status_code/100) == 2:
                ret_ = dict(data)
                ret_['ID'] = spID

        return ret_
