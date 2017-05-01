#!/usr/bin/python

import pdb
import fileinput
import os
import os.path
import gzip
import sys
from pprint import pprint as pp
import argparse
from subprocess import PIPE,Popen

#pdb.set_trace()

SCRIPT = os.path.abspath(sys.argv[0])
BNAME = os.path.basename(SCRIPT)
PARSER = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter, description='Partition and maybe upload data', epilog="""
Following ENV vars need to be present if using --s3_push or --gzip_s3_push
export MY_AWS_URL=<Your AWS URL>
export MY_AWS_ROLE=<Your AWS Role>
export MY_AWS_BUCKET=<Your AWS Bucket>
export MY_AD_USERNAME=<Your AD Domain\\Your AD id>
export MY_AD_PASSWORD=<Your AD Password>
-- OPTIONALLY --
export MY_AWS_ENCRYPTION_KMS_KEYID=<Your arn:aws:kms key>
export MY_AWS_FOLDER=<Folder on AWS to use> - Defaults to top.
export MY_PROXY_HOST=<Host> - Defaults proxy
export MY_PROXY_PORT=<Port> - Defaults to 80""")
PARSER.add_argument('-l', '--log', help='OPTIONAL file to catch stdout and stderr')
PARSER.add_argument('-i', '--infile', help='input file, defaults to stdin', default='-')
MUTUALLY_EXCLUSIVE_GROUP = PARSER.add_mutually_exclusive_group()
MUTUALLY_EXCLUSIVE_GROUP.add_argument('--s3_push',  help='use s3_push.py to stream parts to AWS', action='store_true')
MUTUALLY_EXCLUSIVE_GROUP.add_argument('--gzip_s3_push', help='use s3_push.py with --gzip flag to stream compressed parts to AWS', action='store_true')
MUTUALLY_EXCLUSIVE_GROUP.add_argument('--gzip_disk', help='use gzip to stream compress file parts', action='store_true')
PARSER.add_argument('dir', help='directory where to write file parts or logs for push')
PARSER.add_argument('bname', help='basename to use for the file parts')
PARSER.add_argument('parts', help='number of parts', type=int)
OPTS = vars(PARSER.parse_args())

S3_PUSH_PATH = None
COMPRESSOR = False

if OPTS['s3_push'] or OPTS['gzip_s3_push']:
    S3_PUSH_PATH = os.path.join(os.path.dirname(SCRIPT), 's3_push.py')

    if os.path.isfile(S3_PUSH_PATH) == False:
        PARSER.error('Cannot find {}.'.format(S3_PUSH_PATH))

    for s_ in "MY_AWS_ROLE MY_AWS_BUCKET MY_AWS_URL MY_AD_USERNAME MY_AD_PASSWORD".split():
        if not os.getenv(s_):
            PARSER.error('ENV var {} is not set.'.format(s_))

if OPTS['infile'] != '-' and not os.path.isfile(OPTS['infile']):
    PARSER.error('Cannot find {}.'.format(OPTS['infile']))

DIR = OPTS['dir']
BNAME = OPTS['bname']
PARTS = OPTS['parts']
FILE_PARTS = list()
PIPES = list()

for i_ in range(0, PARTS):
    txtBname_ = "{}-{}.txt".format(BNAME, i_)

    if S3_PUSH_PATH:
        args_ = [S3_PUSH_PATH, '--log', os.path.join(DIR, txtBname_)]

        if os.getenv('MY_AWS_FOLDER'):
            txtBname_ = os.path.join(os.getenv('MY_AWS_FOLDER'), txtBname_)

        if OPTS['gzip_s3_push']:
            args_.append('--gzip')

        args_.append(txtBname_)

        PIPES.append(Popen(args_, stdin=PIPE, universal_newlines=True, close_fds=True))
    else:
        txtBname_ = os.path.join(DIR, txtBname_)

        if OPTS['gzip_disk']:
            COMPRESSOR = True
            FILE_PARTS.append(gzip.open(txtBname_ + '.gz', 'wb'))
        else:
            FILE_PARTS.append(open(txtBname_, 'w'))

for l_ in fileinput.input(files=(OPTS['infile'])):
    part_ = fileinput.lineno() % int(PARTS)
    if S3_PUSH_PATH:
        PIPES[part_].stdin.write(l_)
    else:
        if COMPRESSOR:
            l_ = bytes(l_, 'utf8')

        FILE_PARTS[part_].write(l_)

for pipe_ in PIPES:
    pipe_.communicate()

for fObj_ in FILE_PARTS:
    fObj_.close()
