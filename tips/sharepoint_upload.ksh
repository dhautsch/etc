#!/usr/bin/ksh

AD_USER='ADDOMAIN\puck'
PASS=XXXX

CLOUD_DOC_FOLDER="Shared%20Documents"
SRC_FILE=$HOME/MSG/UPLOAD/hosts.txt

CLOUD_SP=http://sharepoint/sites/top/subsite
CLOUD_SP=https://bogus.sharepoint.com/sites/top/subsite

if echo $CLOUD_SP|grep sharepoint.com > /dev/null
then
    CLOUD_USER='puck@domain.com'
    export HTTPS_PROXY=https://zsproxy.fanniemae.com:9480
else
    true
fi

#
# Set above variables for your site, file, etc.
#
# This script does both upload/download to create the download script
#   ln -s upload_file.ksh download_file.ksh
#

TMP_DIR=$HOME/MSG/UPLOAD
TMP_DIR=$HOME/tmp-$$-upload_file

if test -d $TMP_DIR
then
    true
else
    mkdir -p $TMP_DIR
    trap "rm -rf $TMP_DIR" EXIT
fi

if cd $TMP_DIR
then
    true
else
    echo CD FAILED
    exit 1
fi

AUTH=--ntlm
NETRC_FILE=$TMP_DIR/.netrc

touch $NETRC_FILE 
chmod go-rwx $NETRC_FILE

SITE=$(echo $CLOUD_SP | perl -p -e 's!^https*://!!;s!(:\d+)*/.*!!')

cat > $NETRC_FILE <<EOF
machine $SITE login $AD_USER password $PASS
EOF

export HOME=$TMP_DIR


if echo $CLOUD_SP|grep sharepoint.com > /dev/null
then
    true
else
    case $(basename $0) in
	upload_file.ksh)   exec curl -v -n $AUTH --upload-file $SRC_FILE $CLOUD_SP/$CLOUD_DOC_FOLDER/$(basename $SRC_FILE) ;;
	download_file.ksh) exec curl -v -n $AUTH -o $SRC_FILE $CLOUD_SP/$CLOUD_DOC_FOLDER/$(basename $SRC_FILE) ;;
    esac
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
        <o:Password>$PASS</o:Password>
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

curl -v --connect-timeout 10 --max-time 120 -n $AUTH \
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
    
curl -v --connect-timeout 10 --max-time 120 -n $AUTH \
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

curl -v --connect-timeout 10 --max-time 120 -n $AUTH \
 --data "''" \
 --ciphers AES256-SHA \
 -H "Cookie:$COOKIE1;$COOKIE2" \
 -H 'accept:application/atom+xml;charset=utf-8' \
 -o $CURL_RESP \
 "$CLOUD_SP/_api/contextinfo"

DIGEST=$(perl -lane 'print "Authorization:Bearer $1" if m!<d:FormDigestValue[^>]*>(.*)</d:FormDigestValue!' $CURL_RESP)

if test -z "$DIGEST"
then
    echo GET DIGEST FAILED
    exit 1
fi

SRC_BNAME=$(basename $SRC_FILE)

case $(basename $0) in
    upload_file.ksh)
	curl -v --connect-timeout 10 --max-time 120 -n $AUTH \
	     -H "Cookie:$COOKIE1;$COOKIE2" \
	     -H "$DIGEST" \
	     --ciphers AES256-SHA \
	     --data-binary @$SRC_FILE \
	     -o $CURL_RESP \
	     "$CLOUD_SP/_api/web/getfolderbyserverrelativeurl('$CLOUD_DOC_FOLDER')/Files/Add(url='$SRC_BNAME',overwrite=true)"

	cat $CURL_RESP
	;;
    download_file.ksh)
	curl -v --connect-timeout 10 --max-time 120 -n $AUTH \
	     -H "Cookie:$COOKIE1;$COOKIE2" \
	     -H "$DIGEST" \
	     --ciphers AES256-SHA \
	     -o $SRC_FILE \
	     "$CLOUD_SP/$CLOUD_DOC_FOLDER/$SRC_BNAME"
	;;
esac
