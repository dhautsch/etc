#!/usr/bin/python

from subprocess import PIPE,Popen
from datetime import datetime,timezone
import os
import os.path
import gzip
import sys
import io
import pdb
import argparse
from pprint import pprint as pp
from botocore.client import Config
import boto3
from boto3_SAMLAssertion import get_boto3_SAMLAssertion

#pdb.set_trace()

def zuluTime():
    return datetime.now(timezone.utc).isoformat('T')

MISSING_ENV = False
SCRIPT = os.path.abspath(sys.argv[0])
PARSER = argparse.ArgumentParser(formatter_class=argparse.RawDescriptionHelpFormatter, description='Upload to AWS', epilog="""
Following ENV vars need to be present
export MY_AWS_URL=<Your AWS URL>
export MY_AWS_ROLE=<Your AWS Role>
export MY_AWS_BUCKET=<Your AWS Bucket>
export MY_AD_USERNAME=<Your AD Domain\\Your AD id>
export MY_AD_PASSWORD=<Your AD Password>
-- OPTIONALLY --
export MY_AWS_ENCRYPTION_KMS_KEYID=<Your arn:aws:kms key>
export MY_PROXY_HOST=<Host> - Defaults proxy
export MY_PROXY_PORT=<Port> - Defaults to 80""")

PARSER.add_argument('-z', '--gzip', action='store_true', help='gzip stream on the fly and add .gz extension to file name')
PARSER.add_argument('-l', '--log', help='OPTIONAL file to catch stdout and stderr')
PARSER.add_argument('-i', '--infile', type=argparse.FileType('r'), help='input file, defaults to stdin')
PARSER.add_argument('name', help='file path/name on AWS')
OPTS = vars(PARSER.parse_args())

for s_ in "MY_AWS_URL MY_AWS_ROLE MY_AWS_BUCKET MY_AD_USERNAME MY_AD_PASSWORD".split():
    if not os.getenv(s_):
        PARSER.error('ENV var {} is not set.'.format(s_))

ROLE = os.getenv('MY_AWS_ROLE')
BUCKET = os.getenv('MY_AWS_BUCKET')
KEY = OPTS['name']
LOG = OPTS['log']

if LOG:
    sys.stdout = open(LOG, 'w')
    sys.stderr = open(LOG, 'w')

IDP_URL = os.getenv('MY_AWS_URL')
USERNAME = os.getenv('MY_AD_USERNAME')
USER_PASSWORD = os.getenv('MY_AD_PASSWORD')
PROXY_HOST = os.getenv('MY_PROXY_HOST', 'proxy')
PROXY_PORT = os.getenv('MY_PROXY_PORT', '80')
PROXY_USERNAME = USERNAME.split('\\')[1]

PROXY_URL = 'http://' + PROXY_USERNAME + ':' + USER_PASSWORD + '@' + PROXY_HOST + ':' + PROXY_PORT + '/'

STREAM = io.BytesIO()

if OPTS['gzip']:
    COMPRESSOR = gzip.GzipFile(fileobj=STREAM, mode='w')
    KEY = KEY + '.gz'
else:
    COMPRESSOR = None

SAML_ASSERTION = get_boto3_SAMLAssertion(idp_url=IDP_URL, user_name=USERNAME, user_password=USER_PASSWORD, assume_role=ROLE, proxy_url=PROXY_URL)

if SAML_ASSERTION is None:
    print("Something did not work", file=sys.stderr)
    sys.exit(1)

STS_TOKEN = boto3.client('sts').assume_role_with_saml(**SAML_ASSERTION)

# Get the temporary credentials from the response for the assumed role
CREDENTIALS = STS_TOKEN['Credentials']
SESSION = boto3.session.Session( aws_access_key_id     = CREDENTIALS['AccessKeyId'],
                                 aws_secret_access_key = CREDENTIALS['SecretAccessKey'],
                                 aws_session_token     = CREDENTIALS['SessionToken'],
                                 region_name           = 'us-east-1',
                                 profile_name          = None)
S3 = SESSION.client('s3', config=Config(signature_version='s3v4'))

RESPONSES = []

CREATE_MULTIPART_UPLOAD_PARAMS = { 'Bucket' : BUCKET, 'Key' : KEY }

if os.getenv('MY_AWS_ENCRYPTION_KMS_KEYID'):
    CREATE_MULTIPART_UPLOAD_PARAMS['ServerSideEncryption'] = 'aws:kms'
    CREATE_MULTIPART_UPLOAD_PARAMS['SSEKMSKeyId'] = os.getenv('MY_AWS_ENCRYPTION_KMS_KEYID')

RESPONSE = S3.create_multipart_upload(**CREATE_MULTIPART_UPLOAD_PARAMS)

print('//')
print('// {} create_multipart_upload bucket={} key={}'.format(zuluTime(), BUCKET, KEY))
print('//')

RESPONSES.append(RESPONSE)

UPLOAD_ID = RESPONSE['UploadId']

FO = OPTS['infile']
if FO is None:
    FO = sys.stdin

TELL = 0
TOTAL_SIZE = 0
I = 0
PARTS = []
while True:
    CHUNK = FO.buffer.read(8388608)
    if not CHUNK:
        if COMPRESSOR:
            COMPRESSOR.close()

        I += 1

        TELL = STREAM.tell()
        print('//')
        print('// {} last upload_part-{} is tell={} before reset'.format(zuluTime(), I, TELL))
        print('//')

        STREAM.seek(0)
        TELL = STREAM.tell()

        RESPONSE = S3.upload_part(Bucket=BUCKET, Key=KEY, UploadId=UPLOAD_ID, Body=STREAM, PartNumber=I)
        RESPONSES.append(RESPONSE)
        PARTS.append({'ETag':RESPONSE['ETag'],'PartNumber':I})
        print('//')
        print('// {} last upload_part-{} is tell={} after reset, read={}'.format(zuluTime(), I, TELL, TOTAL_SIZE))
        print('//')

        RESPONSE = S3.complete_multipart_upload(Bucket=BUCKET, Key=KEY, UploadId=UPLOAD_ID, MultipartUpload={'Parts': PARTS})
        RESPONSES.append(RESPONSE)
        print('//')
        print('// {} complete_multipart_upload TOTAL_SIZE={}'.format(zuluTime(), TOTAL_SIZE))
        print('//')

        pp({ 'RESPONSES' : RESPONSES, 'PARTS' : PARTS })

        break

    if COMPRESSOR:
        COMPRESSOR.write(CHUNK)
    else:
        STREAM.write(CHUNK)

    TOTAL_SIZE += len(CHUNK)

    TELL = STREAM.tell()

    if TELL > 10 << 20:
        I += 1

        print('//')
        print('// {} upload_part-{} is tell={} before reset'.format(zuluTime(), I, TELL))
        print('//')

        STREAM.seek(0)
        TELL = STREAM.tell()

        RESPONSE = S3.upload_part(Bucket=BUCKET, Key=KEY, UploadId=UPLOAD_ID, Body=STREAM, PartNumber=I)
        RESPONSES.append(RESPONSE)
        PARTS.append({'ETag':RESPONSE['ETag'],'PartNumber':I})
        print('//')
        print('// {} upload_part-{} is tell={} after reset, read={}'.format(zuluTime(), I, TELL, TOTAL_SIZE))
        print('//')

        STREAM.seek(0)
        TELL = STREAM.tell()
        STREAM.truncate()
        print('//')
        print('// {} upload_part-{} is tell={} before truncate'.format(zuluTime(), I, TELL))
        print('//')
