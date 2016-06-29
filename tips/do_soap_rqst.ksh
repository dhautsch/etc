#!/usr/bin/ksh
#
#
# Replace HOST PORT RQST below
#
#
TOP=$(cd $(dirname $0) && pwd)

HOST=gandalf
PORT=8001
RQST=$TOP/PUT.XML

cat > $RQST <<EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:urn="urn:siperian.api">
   <soapenv:Header/>
   <soapenv:Body>
      <urn:executeBatchAutomerge>
         <urn:username></urn:username>
         <urn:password>
            <urn:password></urn:password>
            <urn:encrypted>false</urn:encrypted>
         </urn:password>
         <urn:orsId>ORS_ID</urn:orsId>
         <urn:tableName>C_BO_TEST</urn:tableName>
      </urn:executeBatchAutomerge>
   </soapenv:Body>
</soapenv:Envelope>
EOF

#
# No changes past this point
#

ENDPOINT=http://$HOST:$PORT/cmx/services/SifService

TMP=/tmp/PUT-$$-request.xml

export USER=scott
export PASS=tiger

trap 'rm $TMP' 0 1 3 15

set -x

touch $TMP
chmod go-rwx $TMP

perl -pe 's!(<urn:username>)(</urn:username>)!$1$ENV{USER}$2!;s!(password>)(</urn:password)!$1$ENV{PASS}$2!' < $RQST > $TMP

curl --header "Content-Type: text/xml;charset=UTF-8" --header "SOAPAction:urn:executeBatchAutomerge" --data @$TMP $ENDPOINT

set +x

echo
