import time
import json
import requests
from requests_ntlm import HttpNtlmAuth

class SharePointList:
    """Class to interact with SharePoint List

    SP = SharePointList('user@pass', 'http://sharepoint', 'Bogus')

    listMeta_ = SP.getMeta()
    pp(listMeta_)

    ret_ = SP.getItems()
    if ret_:
        for item_ in ret_:
            print('First  fetch ' + item_['Title'])

    ret_ = SP.getItems({'$top': listMeta_['ItemCount']})
    if ret_:
        for item_ in ret_:
            print('Second fetch ' + item_['Title'])

    ret_ = SP.merge({ '__metadata': { 'type': listMeta_['ListItemEntityTypeFullName'] }, 'Title': 'New_bogus-201803051650' }, 74)

    ret_ = SP.append({ '__metadata': { 'type': listMeta_['ListItemEntityTypeFullName'] }, 'Title': 'Updated---201803021650' })

    ret_ = SP.merge( { 'Title': 'New_bogus-201803051650' }, 74)
    
    ret_ = SP.append({ 'Title': 'Updated---201803021650' })

    ret_ = SP.getItem(74)

    ret_ = SP.remove(73)
    """

    def __init__(self, connect, url, spList):
        self._digest = None
        self._ListItemEntityTypeFullName = None
        self._httpAuth = None
        self._session = None
        self._connect = connect.decode("utf-8").split('@')
        self._spList = spList
        self._url = url
        self._digestURL = '{}/_api/contextinfo'.format( self._url )
        self._spList = '{}/_api/lists/getByTitle%28%27{}%27%29'.format( self._url, self._spList)
        self._spListItems = self._spList + '/items'
        self._headerForGet    = { 'accept' : 'application/json;odata=verbose' }
        self._headerForUpsert = { 'accept' : 'application/json;odata=verbose', 'content-type' : 'application/json;odata=verbose', 'IF-MATCH' : '*' }

    def getSession(self):
        if self._session is None:
            self._session = requests.Session()

            if self._session is None:
                print("requests.Session() returned None")
                sys.exit(1)

        return self._session

    def getHttpAuth(self):
        if self._httpAuth is None:
            self._httpAuth = HttpNtlmAuth(self._connect[0], self._connect[1], self._session)

            if self._httpAuth is None:
                print("HttpNtlmAuth returned None")
                sys.exit(1)

        return self._httpAuth
        
    def getDigest(self):
        if self._digest:
            t_ = (int(time.time()) - self._digest['CreateTimeForDigest']) + 300

            if t_ > self._digest['FormDigestTimeoutSeconds']:
                self._digest = None

        if self._digest is None:
            
            response_ = self.getSession().post(self._digestURL, data = {}, auth = self.getHttpAuth(), headers = self._headerForGet)

            if response_.status_code == 200:
                o_ = response_.json()
                self._digest = dict()

                for s_ in [ 'FormDigestTimeoutSeconds', 'FormDigestValue', 'SiteFullUrl', 'WebFullUrl'  ]:
                    self._digest[s_] = o_['d']['GetContextWebInformation'][s_]

                self._digest['CreateTimeForDigest'] = int(time.time())

        return self._digest

    def getMeta(self):
        ret_ = None

        response_ = self.getSession().get(self._spList, auth = self.getHttpAuth(), headers = self._headerForGet)
        if response_.status_code == 200:
            o_ = response_.json()
            ret_ = dict()

            for s_ in [ 'Created', 'LastItemDeletedDate', 'ListItemEntityTypeFullName', 'LastItemModifiedDate', 'ItemCount', 'Title' ]:
                ret_[s_] = o_['d'][s_]

        return ret_

    def getItems(self, spListItemsParams = None):
        ret_ = None

        if spListItemsParams is None:
            response_ = self.getSession().get(self._spListItems, auth = self.getHttpAuth(), headers = self._headerForGet)
        else:
            response_ = self.getSession().get(self._spListItems, auth = self.getHttpAuth(), headers = self._headerForGet, params = spListItemsParams)

        if response_.status_code == 200:
            o_ = response_.json()
            ret_ = o_['d']['results']

        return ret_

    def getItem(self, spItemID):
        ret_ = None

        url_ = '{}%28{}%29'.format( self._spListItems, spItemID)
        response_ = self.getSession().get(url_, auth = self.getHttpAuth(), headers = self._headerForGet)

        if response_.status_code == 200:
            o_ = response_.json()
            ret_ = o_['d']

        return ret_
        
    def remove(self, spItemID):
        ret_ = None

        if spItemID:
            digest_ = self.getDigest()

            if digest_:
                headers_ = self._headerForUpsert.copy()
                headers_['X-RequestDigest'] = digest_['FormDigestValue']
                url_ = '{}%28{}%29'.format( self._spListItems, spItemID)

                response_ = self.getSession().delete(url_, auth = self.getHttpAuth(), headers = headers_)

                if response_.status_code == 200:
                    ret_ = { 'ID' : spItemID, 'Id' : spItemID, 'REST_ACTION' : 'DELETE', 'HTTP_STATUS' : response_.status_code }

        return ret_
        
    def getListItemEntityTypeFullName(self):
        ret_ = None

        if self._ListItemEntityTypeFullName is None:
            listMeta_ = self.getMeta()

            if listMeta_ and 'ListItemEntityTypeFullName' in listMeta_:
                self._ListItemEntityTypeFullName = listMeta_['ListItemEntityTypeFullName']

        if self._ListItemEntityTypeFullName:
            ret_ = self._ListItemEntityTypeFullName

        return ret_

    def merge(self, spData, spItemID):
        ret_ = None

        if spData and spItemID:
            digest_ = self.getDigest()

            if digest_:
                headers_ = self._headerForUpsert.copy()
                headers_['X-RequestDigest'] = digest_['FormDigestValue']
                url_ = '{}%28{}%29'.format( self._spListItems, spItemID)
                data_ = spData

                if '__metadata' not in data_ and self.getListItemEntityTypeFullName():
                        data_ = data_.copy()
                        data_['__metadata'] = { 'type': self._ListItemEntityTypeFullName }

                response_ = self.getSession().request('MERGE', url_, auth = self.getHttpAuth(), headers = headers_, data = json.dumps(data_))

                if response_.status_code == 204:
                    ret_ = { 'ID' : spItemID, 'Id' : spItemID, 'REST_ACTION' : 'MERGE', 'HTTP_STATUS' : response_.status_code }

        return ret_


    def append(self, spData):
        ret_ = None

        if spData:
            digest_ = self.getDigest()

            if digest_:
                headers_ = self._headerForUpsert.copy()
                headers_['X-RequestDigest'] = digest_['FormDigestValue']
                data_ = spData

                if '__metadata' not in data_ and self.getListItemEntityTypeFullName():
                        data_ = data_.copy()
                        data_['__metadata'] = { 'type': self._ListItemEntityTypeFullName }

                response_ = self.getSession().post(self._spListItems, auth = self.getHttpAuth(), headers = headers_, data = json.dumps(data_))

                if response_.status_code == 201:
                    o_ = response_.json()
                    ret_ = o_['d']

        return ret_
