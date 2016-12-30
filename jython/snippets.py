os.environ['TZ'] = 'US/Eastern'
time.tzset()

def toSeconds(s):
        ret_ = None

        if s:
                ret_ = int(time.mktime(time.strptime(s, "%Y-%m-%dT%H:%M:%S"))) # iso timestamp

        return ret_

def qx(cmd):
        import subprocess

        pipe_ = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True, bufsize=-1, close_fds=True)
        try:
                for l_ in pipe_.stdout:
                        s_ = l_.rstrip()
                        if len(s_) > 0: yield(s_)
        finally:
                pipe_.stdout.close()

HOST = ''.join(qx('uname -n'))

BANNER = [s_ for s_ in """
DATE
DEBUG
ERROR
INFO
WARN
LOG
""".split("\n") if s_]

LEVELS = [s_ for s_ in BANNER if s_ != 'DATE' and s_ != 'LOG']


import logging
import subprocess
import os

logging.basicConfig(filename='python.log', level=logging.DEBUG, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logging.warning('this is just an eample.')

s = subprocess.call(["ls", "-ltr"])
s=os.system('echo $PWD')
print("s : %s" % (s))


from wsgiref.simple_server import make_server

# Every WSGI application must have an application object - a callable
# object that accepts two arguments. For that purpose, we're going to
# use a function (note that you're not limited to a function, you can
# use a class for example). The first argument passed to the function
# is a dictionary containing CGI-style envrironment variables and the
# second variable is the callable object (see :pep:`333`)
def hello_world_app(environ, start_response):
    status = '200 OK' # HTTP Status
    headers = [('Content-type', 'text/plain')] # HTTP Headers
    start_response(status, headers)

    # The returned object is going to be printed
    return ["Hello World"]

httpd = make_server('', 8000, hello_world_app)
print "Serving on port 8000..."

# Serve until process is killed
httpd.serve_forever()



import urllib2
import json

#----------------#
# Define the URL #
#----------------#

url = "http://host:8000/cgi-bin/xx.pl"

opener = urllib2.build_opener()
opener.addheaders.append(('Content-type', 'application/json;charset=utf-8'))
f = opener.open(url)
v = f.read()
q = json.loads(v)
print v
print q
