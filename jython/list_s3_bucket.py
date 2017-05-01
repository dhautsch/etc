#!/usr/bin/python

import os
import os.path
import sys
import pdb
from pprint import pprint as pp
from botocore.client import Config
import boto3
from boto3_SAMLAssertion import get_boto3_SAMLAssertion

SCRIPT = os.path.abspath(sys.argv[0])

for s_ in "MY_AWS_URL MY_AWS_ROLE MY_AWS_BUCKET MY_AD_USERNAME MY_AD_PASSWORD".split():
    if not os.getenv(s_):
        print("""Usage {} - list bucket contents

Following ENV vars need to be present
export MY_AWS_URL=<Your AWS URL>
export MY_AWS_ROLE=<Your AWS Role>
export MY_AWS_BUCKET=<Your AWS Bucket>
export MY_AD_USERNAME=<Your AD Domain\\Your AD id>
export MY_AD_PASSWORD=<Your AD Password>
-- OPTIONALLY --
export MY_PROXY_HOST=<Host> - defaults proxy
export MY_PROXY_PORT=<Port> - defaults to 80
export MY_AWS_BUCKET_KEY_PREFIX - Limits the response to keys that begin with the specified prefix.""".format(SCRIPT))
        sys.exit(0)

ROLE = os.getenv('MY_AWS_ROLE')
BUCKET = os.getenv('MY_AWS_BUCKET')

IDP_URL = os.getenv('MY_AWS_URL')
USERNAME = os.getenv('MY_AD_USERNAME')
USER_PASSWORD = os.getenv('MY_AD_PASSWORD')
PROXY_HOST = os.getenv('MY_PROXY_HOST', 'proxy')
PROXY_PORT = os.getenv('MY_PROXY_PORT', '80')
PROXY_USERNAME = USERNAME.split('\\')[1]
PROXY_URL = 'http://' + PROXY_USERNAME + ':' + USER_PASSWORD + '@' + PROXY_HOST + ':' + PROXY_PORT + '/'

#pdb.set_trace()

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

S3 = SESSION.client('s3')

LIST_OBJECTS_PARAMS = { 'Bucket' : os.getenv('MY_AWS_BUCKET') }
if 'MY_AWS_BUCKET_KEY_PREFIX' in os.environ:
    LIST_OBJECTS_PARAMS['Prefix'] = os.getenv('MY_AWS_BUCKET_KEY_PREFIX')

S3_OBJS = S3.list_objects(**LIST_OBJECTS_PARAMS)

#pdb.set_trace()

for o_ in S3_OBJS['Contents']:
    print("{} {} {} {}".format(o_['Owner']['DisplayName'], o_['Size'], o_['LastModified'].isoformat(sep='T'), o_['Key']))
