"""
Put this file in $HOME/MyPythonModules then in your code do following
  import os
  import sys
  sys.path.insert(0, os.environ['HOME'] + '/MyPythonModules')
Kinda like the use lib in perl
  use lib "$ENV{HOME}/MyPerlModules";
"""

import shlex
import subprocess
import re

def qx(cmd):
    # a_ = shlex.split(cmd)
    # pipe_ = subprocess.Popen(a_, shell=False, stdout=subprocess.PIPE)
    pipe_ = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
    try:
        for l_ in pipe_.stdout:
            s_ = l_.rstrip()
            if len(s_) > 0: yield(s_)
    finally:
        pipe_.stdout.close()

def getProps(propFile, props):
    ret_ = None

    if propFile and props:
        with open(propFile) as f_:
            cntLkupProps_ = len(props)

            for line_ in f_ :
                for k_, v_ in props.items():
                    m_ = re.match(v_ + '=' + '(\S+)', line_)
                    if m_ :
                        if ret_ is None:
                            ret_ = dict()

                        ret_[k_] = m_.group(1)

                        if ret_ and cntLkupProps_ == len(ret_):
                            break

                if ret_ and cntLkupProps_ == len(ret_):
                    break

    return ret_
