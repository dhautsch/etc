import json
import pdb
import re
from datetime import datetime, timedelta
import xml.etree.ElementTree as et
from xml.sax.saxutils import escape
from pprint import pprint as pp
import requests
from requests_ntlm import HttpNtlmAuth

class SharePointList(requests.Session):
    """Class to interact with SharePoint List

    os.environ['HTTPS_PROXY'] = 'http://proxy' # set if using proxy

    SP = SharePointList('user', 'pass', 'http://sharepoint', 'Bogus')

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

    ret_ = SP.append({ '__metadata': { 'type': listMeta_['ListItemEntityTypeFullName'] }, 'Title': 'New_Item ' + time.asctime( time.localtime(time.time())) })

    ret_ = SP.merge({ '__metadata': { 'type': listMeta_['ListItemEntityTypeFullName'] }, 'Title': 'Updated ' + time.asctime( time.localtime(time.time())) }, ret_['ID'])

    ret_ = SP.append({ 'Title': 'New_Item ' + time.asctime( time.localtime(time.time())) })

    ret_ = SP.merge( { 'Title': 'Updated ' + time.asctime( time.localtime(time.time())) }, ret_['ID'])

    ret_ = SP.getItem(ret_['ID'])

    ret_ = SP.remove(ret_['ID'])

    The saml code for connecting to sharepoint.com was inspired by sharepy
    """

    MSOnline = "https://login.microsoftonline.com/extSTS.srf"
    SAML_NS = {
        "wsse": "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd",
        "d": "http://schemas.microsoft.com/ado/2007/08/dataservices"
    }
    SAML = """<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"
      xmlns:a="http://www.w3.org/2005/08/addressing"
      xmlns:u="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
  <s:Header>
    <a:Action s:mustUnderstand="1">http://schemas.xmlsoap.org/ws/2005/02/trust/RST/Issue</a:Action>
    <a:ReplyTo>
      <a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address>
    </a:ReplyTo>
    <a:To s:mustUnderstand="1">https://login.microsoftonline.com/extSTS.srf</a:To>
    <o:Security s:mustUnderstand="1"
       xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <o:UsernameToken>
        <o:Username>{username}</o:Username>
        <o:Password>{password}</o:Password>
      </o:UsernameToken>
    </o:Security>
  </s:Header>
  <s:Body>
    <t:RequestSecurityToken xmlns:t="http://schemas.xmlsoap.org/ws/2005/02/trust">
      <wsp:AppliesTo xmlns:wsp="http://schemas.xmlsoap.org/ws/2004/09/policy">
        <a:EndpointReference>
          <a:Address>{site}</a:Address>
        </a:EndpointReference>
      </wsp:AppliesTo>
      <t:KeyType>http://schemas.xmlsoap.org/ws/2005/05/identity/NoProofKey</t:KeyType>
      <t:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</t:RequestType>
      <t:TokenType>urn:oasis:names:tc:SAML:1.0:assertion</t:TokenType>
    </t:RequestSecurityToken>
  </s:Body>
</s:Envelope>"""

    REQUESTS_LOG = None

    def debugOn():
        if SharePointList.REQUESTS_LOG is None:
            try:
                import logging
                import http.client as http_client
            except ImportError:
                # Python 2
                import httplib as http_client

            http_client.HTTPConnection.debuglevel = 1

            # You must initialize logging, otherwise you'll not see debug output.
            logging.basicConfig()
            logging.getLogger().setLevel(logging.DEBUG)
            SharePointList.REQUESTS_LOG = logging.getLogger("requests.packages.urllib3")
            SharePointList.REQUESTS_LOG.setLevel(logging.DEBUG)
            SharePointList.REQUESTS_LOG.propagate = True

    def __init__(self, username, password, url, spList):
        super().__init__()

        self._expire = datetime.now()
        self._ListItemEntityTypeFullName = None
        self._digest = None
        self._auth = None
        self._saml = None
        self._samlCookie = None
        self._username = username
        self._password = password
        self._spList = spList
        self._url = url
        self._site = re.sub(r"^https?://", "", url)
        self._site = re.sub(r'(:\d+)*/.*', "", self._site)
        self._digestURL = '{}/_api/contextinfo'.format( self._url )
        self._spList = '{}/_api/lists/getByTitle%28%27{}%27%29'.format( self._url, self._spList)
        self._spListItems = self._spList + '/items'

        # insert username and password into SAML request after escaping special characters
        if re.search(r'sharepoint\.com', self._site):
            self._saml = SharePointList.SAML.format(username=escape(self._username),
                                                    password=escape(self._password),
                                                    site=self._site)

            token_ = None
            response_ = requests.post(SharePointList.MSOnline, data=self._saml)
            try:
                root_ = et.fromstring(response_.text)
                token_ = root_.find(".//wsse:BinarySecurityToken", SharePointList.SAML_NS).text
            except:
                token_ = None
                print("Token request failed at {}. Check your username and password.".format(SharePointList.MSOnline))

            if token_:
                # Request access token from sharepoint.com site
                response_ = requests.post("https://" + self._site + "/_forms/default.aspx?wa=wsignin1.0",
                                          data = token_, headers = { "Host" : self._site } )

                # Create access cookie from returned headers
                self._samlCookie = self._buildcookie(response_.cookies)
                if self._samlCookie:
                    self.headers.update( { "Cookie" : self._samlCookie } )
        else:
            # sharepoint is local
            self._auth = HttpNtlmAuth(self._username, self._password, self)
            if self._auth is None:
                print("HttpNtlmAuth returned None")
                self._session = None

        if self._auth or self._samlCookie:
            self.headers.update( { 'accept' : 'application/json;odata=verbose'
                                 , 'content-type' : 'application/json;odata=verbose'
                                 , 'IF-MATCH' : '*' } )
            self._redigest()

            listMeta_ = self.getMeta()
            if listMeta_ and 'ListItemEntityTypeFullName' in listMeta_:
                self._ListItemEntityTypeFullName = listMeta_['ListItemEntityTypeFullName']
            
        if self._ListItemEntityTypeFullName:
            pass
        else:
            print("CONSTRUCTOR FAILED")
            sys.exit(1)

        pass

    def _buildcookie(self, cookies):
        """Create session cookie from response cookie dictionary inspired by sharepy"""
        if "rtFa" in cookies and "FedAuth" in cookies:
            return "rtFa=" + cookies["rtFa"] + "; FedAuth=" + cookies["FedAuth"]
        else:
            return None

    def _redigest(self):
        """Check and refresh site's request form digest"""

#        pdb.set_trace()

        if self._expire <= datetime.now():
            if self._auth:
                response_ = self.post(self._digestURL, data = "", auth = self._auth)
            else:
                response_ = self.post(self._digestURL, data = "")

            # Parse digest text and timeout from XML
            try:
                o_ = response_.json()

                timeout_ = int(o_['d']['GetContextWebInformation']['FormDigestTimeoutSeconds'])
                # Calculate digest expiry time
                self._expire = datetime.now() + timedelta(seconds=timeout_)

                self._digest = o_['d']['GetContextWebInformation']['FormDigestValue']

                if self._samlCookie:
                    self.headers.update( { "Authorization" : "Bearer " + self._digest } )
                    self._samlCookie = self._buildcookie(response_.cookies)
                    self.headers.update( { "Cookie" :  self._samlCookie } )
                else:
                    self.headers.update( { "X-RequestDigest" : self._digest } )
            except:
                return None

        return self._digest

    def _addMetaListItemEntityTypeFullName(self, spData):
        ret_ = spData
        
        if ret_ and '__metadata' not in ret_:
            ret_ = ret_.copy()
            ret_['__metadata'] = { 'type': self._ListItemEntityTypeFullName }

        return ret_

    def getMeta(self):
        ret_ = None
        url_ = self._spList

        if self._auth:
            response_ = self.get(url_, auth = self._auth)
        else:
            response_ = self.get(url_)

        if response_.status_code == 200:
            o_ = response_.json()
            ret_ = dict()

            for s_ in ( 'Created', 'Description', 'Fields', 'Id', 'Items'
                        , 'LastItemDeletedDate', 'ListItemEntityTypeFullName'
                        , 'LastItemModifiedDate', 'ItemCount', 'Title' ):
                ret_[s_] = o_['d'][s_]

        return ret_

    def getItems(self, getItemsParams = None):
        ret_ = None
        url_ = self._spListItems

        if self._auth:
            response_ = self.get(url_, auth = self._auth, params = getItemsParams)
        else:
            response_ = self.get(url_, params = getItemsParams)

        if response_.status_code == 200:
            o_ = response_.json()
            ret_ = o_['d']['results']

        return ret_

    def getItem(self, spItemID):
        ret_ = None

        if spItemID:
            url_ = '{}%28{}%29'.format( self._spListItems, spItemID)
            if self._auth:
                response_ = self.get(url_, auth = self._auth)
            else:
                response_ = self.get(url_)

            if response_.status_code == 200:
                o_ = response_.json()
                ret_ = o_['d']

        return ret_
        
    def remove(self, spItemID):
        ret_ = None

        if spItemID:
            url_ = '{}%28{}%29'.format( self._spListItems, spItemID)

            self._redigest()
            
            if self._auth:
                response_ = self.delete(url_, auth = self._auth)
            else:
                response_ = self.delete(url_)

            if response_.status_code == 200:
                ret_ = { 'ID' : spItemID, 'Id' : spItemID, 'REST_ACTION' : 'DELETE', 'HTTP_STATUS' : response_.status_code }

        return ret_
        
    def append(self, spData):
        ret_ = None

        if spData:
            self._redigest()

            url_ = self._spListItems

            spData = self._addMetaListItemEntityTypeFullName(spData)
            spData = json.dumps(spData)

            if self._auth:
                response_ = self.post(url_, auth = self._auth, data = spData)
            else:
                response_ = self.post(url_, data = spData)

            if response_.status_code == 201:
                o_ = response_.json()
                ret_ = o_['d']

        return ret_

    def merge(self, spData, spItemID):
        ret_ = None

        if spData and spItemID:
            self._redigest()

            url_ = '{}%28{}%29'.format( self._spListItems, spItemID)

            spData = self._addMetaListItemEntityTypeFullName(spData)
            spData = json.dumps(spData)

            if self._auth:
                response_ = self.request('MERGE', url_, auth = self._auth, data = spData)
            else:
                response_ = self.request('MERGE', url_, data = spData)

            if response_.status_code == 204:
                ret_ = { 'ID' : spItemID, 'Id' : spItemID, 'REST_ACTION' : 'MERGE', 'HTTP_STATUS' : response_.status_code }

        return ret_
