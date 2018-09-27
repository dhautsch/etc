#!/usr/bin/ksh
#
# Hack the AD_DOMAIN and CLOUD_USER variables if needed
#
#set -x

test -z "$XFER_SP_FILE_USER" && USAGE=t
test -z "$XFER_SP_FILE_PASSWORD" && USAGE=t
test "$#" != 2 && USAGE=t

DOWNLOAD=$(echo $1|grep //)
UPLOAD=$(echo $2|grep //)
test -z "$DOWNLOAD" && test -z "$UPLOAD" && USAGE=t
test -n "$DOWNLOAD" && test -n "$UPLOAD" && USAGE=t

if test -n "$USAGE"
then
    echo Upload Usage   : $0 /etc/hosts  https://yoyodyne.sharepoint.com/sites/etl/Shared%20Documents/hosts.txt
    echo Download Usage : $0 https://yoyodyne.sharepoint.com/sites/etl/Shared%20Documents/hosts.txt /tmp/hosts.txt
    echo Env Var XFER_SP_FILE_USER should contain ldap user id
    echo Env Var XFER_SP_FILE_PASSWORD should contain password
    exit 1
fi

if test -n "$DOWNLOAD"
then
    CLOUD_SP=$DOWNLOAD
    FILE=$2
else
    CLOUD_SP=$UPLOAD
    FILE=$1
fi

AD_DOMAIN=YOYODYNE
AD_USER="$AD_DOMAIN\\$XFER_SP_FILE_USER"

if echo $CLOUD_SP|grep sharepoint.com > /dev/null
then
    CLOUD_USER="$XFER_SP_FILE_USER@yoyodyne.com"
    export HTTPS_PROXY=https://proxy.yoyodyne.com:9000
else
    true
fi

if test -n "$XFER_SP_FILE_VERBOSE"
then
    CURL_NOISE=-v
else
    CURL_NOISE=-s
fi

TMP_DIR=/tmp/tmp-$$-$(basename $0)
mkdir -p $TMP_DIR || exit 1
trap "rm -rf $TMP_DIR" EXIT

cd $TMP_DIR || exit 1

AUTH=--ntlm
NETRC_FILE=$TMP_DIR/.netrc
CURL=/usr/bin/curl

touch $NETRC_FILE 
chmod go-rwx $NETRC_FILE

SITE=$(echo $CLOUD_SP | perl -p -e 's!^https*://!!;s!(:\d+)*/.*!!')

cat > $NETRC_FILE <<EOF
machine $SITE login $AD_USER password $XFER_SP_FILE_PASSWORD
EOF

export HOME=$TMP_DIR

if echo $CLOUD_SP|grep sharepoint.com > /dev/null
then
    CLOUD_FILE=$(basename $CLOUD_SP)
    CLOUD_SP=$(dirname $CLOUD_SP)
    CLOUD_DOC_FOLDER=$(basename $CLOUD_SP)
    CLOUD_SP=$(dirname $CLOUD_SP)
else
    if test -n "$UPLOAD"
    then
	exec $CURL $CURL_NOISE -n $AUTH --upload-file $FILE $CLOUD_SP
    else
	exec $CURL $CURL_NOISE -n $AUTH -o $FILE $CLOUD_SP
    fi
fi

AUTH=--proxy-anyauth
COOKIE_FILE=$TMP_DIR/Cookies.txt
CURL_RESP=$TMP_DIR/CurlResponse.txt
SAML_FILE=$TMP_DIR/SAML.dat

for p in $COOKIE_FILE $CURL_RESP $SAML_FILE
do
    touch $p
    chmod go-rwx $p
done

cat > $SAML_FILE <<EOF
<s:Envelope xmlns:s='http://www.w3.org/2003/05/soap-envelope'
      xmlns:a='http://www.w3.org/2005/08/addressing'
      xmlns:u='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'>
  <s:Header>
    <a:Action s:mustUnderstand='1'>http://schemas.xmlsoap.org/ws/2005/02/trust/RST/Issue</a:Action>
    <a:ReplyTo>
      <a:Address>http://www.w3.org/2005/08/addressing/anonymous</a:Address>
    </a:ReplyTo>
    <a:To s:mustUnderstand='1'>https://login.microsoftonline.com/extSTS.srf</a:To>
    <o:Security s:mustUnderstand='1'
       xmlns:o='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'>
      <o:UsernameToken>
        <o:Username>$CLOUD_USER</o:Username>
        <o:Password>$XFER_SP_FILE_PASSWORD</o:Password>
      </o:UsernameToken>
    </o:Security>
  </s:Header>
  <s:Body>
    <t:RequestSecurityToken xmlns:t='http://schemas.xmlsoap.org/ws/2005/02/trust'>
      <wsp:AppliesTo xmlns:wsp='http://schemas.xmlsoap.org/ws/2004/09/policy'>
        <a:EndpointReference>
          <a:Address>$SITE</a:Address>
        </a:EndpointReference>
      </wsp:AppliesTo>
      <t:KeyType>http://schemas.xmlsoap.org/ws/2005/05/identity/NoProofKey</t:KeyType>
      <t:RequestType>http://schemas.xmlsoap.org/ws/2005/02/trust/Issue</t:RequestType>
      <t:TokenType>urn:oasis:names:tc:SAML:1.0:assertion</t:TokenType>
    </t:RequestSecurityToken>
  </s:Body>
</s:Envelope>
EOF

$CURL $CURL_NOISE --connect-timeout 10 --max-time 120 -n $AUTH \
 -o $CURL_RESP \
 --data @$SAML_FILE \
 --ciphers AES256-SHA \
 -H 'accept:application/atom+xml;charset=utf-8' \
 https://login.microsoftonline.com/extSTS.srf

SAML_TOKEN=$(
    perl -lane 'print $1 if m!<wsse:BinarySecurityToken[^>]*>(.*)</wsse:BinarySecurityToken!' $CURL_RESP | \
	perl -p -e 's/&amp;/&/sg;s/&lt;/</sg;s/&gt;/>/sg;s/&quot;/"/sg;'
)

if test -n "$SAML_TOKEN"
then
    echo $SAML_TOKEN > $SAML_FILE
else
    echo GET SAML TOKEN FAILED
    exit 1
fi
    
$CURL $CURL_NOISE --connect-timeout 10 --max-time 120 -n $AUTH \
 -o /dev/null \
 -c $COOKIE_FILE \
 --data @$SAML_FILE \
 --ciphers AES256-SHA \
 -H "HOST:$SITE" \
 -L "https://$SITE/_forms/default.aspx?wa=wsignin1.0"

if test $(egrep '(rtFa|FedAuth)' $COOKIE_FILE | wc -l) != "2"
then
    echo GET COOKIES FAILED
    exit 1
fi

COOKIE1=$(perl -lane 'print "$1=$2" if m!(rtFa)\s+(\S+)!' $COOKIE_FILE)
COOKIE2=$(perl -lane 'print "$1=$2" if m!(FedAuth)\s+(\S+)!' $COOKIE_FILE)

$CURL $CURL_NOISE --connect-timeout 10 --max-time 120 -n $AUTH \
 --data "''" \
 --ciphers AES256-SHA \
 -H "Cookie:$COOKIE1;$COOKIE2" \
 -H 'accept:application/atom+xml;charset=utf-8' \
 -o $CURL_RESP \
 "$CLOUD_SP/_api/contextinfo"

DIGEST=$(perl -lane 'print "Authorization:Bearer $1" if m!<d:FormDigestValue[^>]*>(.*)</d:FormDigestValue!' $CURL_RESP)
DIGEST_TIMEOUT=$(perl -lane 'print $1 if m!<d:FormDigestTimeoutSeconds[^>]*>(.*)</d:FormDigestTimeoutSeconds!' $CURL_RESP)

if test -z "$DIGEST"
then
    echo GET DIGEST FAILED
    exit 1
fi

if test -n "$UPLOAD"
then
    $CURL $CURL_NOISE --connect-timeout 10 --max-time 120 -n $AUTH \
	 -H "Cookie:$COOKIE1;$COOKIE2" \
	 -H "$DIGEST" \
	 --ciphers AES256-SHA \
	 --data-binary @$FILE \
	 -o $CURL_RESP \
	 "$CLOUD_SP/_api/web/getfolderbyserverrelativeurl('$CLOUD_DOC_FOLDER')/Files/Add(url='$CLOUD_FILE',overwrite=true)"

	cat $CURL_RESP
else
	$CURL $CURL_NOISE --connect-timeout 10 --max-time 120 -n $AUTH \
	     -H "Cookie:$COOKIE1;$COOKIE2" \
	     -H "$DIGEST" \
	     --ciphers AES256-SHA \
	     -o $FILE \
	     "$CLOUD_SP/$CLOUD_DOC_FOLDER/$CLOUD_FILE"
fi
