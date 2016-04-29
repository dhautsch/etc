import urllib
import urllib2
import base64
import json
import getpass
import httplib 

#----------------#
# Define the URL #
#----------------#

url = "https://auimperva-m01a:8083/SecureSphere/api/v1/auth/session"

#-------------------------------#
# Define authentication (Basic) #
#-------------------------------#
u = "s6usoh"
p = getpass.getpass("MX Password:")
authKey = base64.b64encode( u + ":" + p )
print authKey

#----------------#
# Create headers #
#----------------#

headers = {"Content-Type":"application/json;charset=utf-8", "Authorization":"Basic " + authKey}
data = {"param":"value"}
request = urllib2.Request(url)

#----------------#
# post form data #
#----------------#
request.add_data(urllib.urlencode(data))

#---------------------------#
# Add headers to the stream #
#---------------------------#
for key,value in headers.items():
  request.add_header(key,value)

#-------------------------------#
# send request and get response #
#-------------------------------#
r = urllib2.urlopen(request)

# Get JSESSIONID version 1
data = json.load(r)
bytestring = data["session-id"].encode('utf-8');
# Get JSESSIONID version 2
# bytestring = r.headers.get('Set-Cookie')
print bytestring

# -------------------------------- Get all sites ----------------------------- #

#----------------#
# Create headers #
#----------------#

opener = urllib2.build_opener()
opener.addheaders.append(('Content-type', 'application/json;charset=utf-8'))
opener.addheaders.append(('Cookie', bytestring))
f = opener.open("https://auimperva-m01a:8083/SecureSphere/api/v1/conf/sites")
v = f.read()
q = json.loads(v)
print q
print v
