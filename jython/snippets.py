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
