#!/bin/bash

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

ORGNAME=mytestorg
HOSTNAME=streaming.example.com

KEY_LENGTH=4096
DIGEST=sha512
DAYS_VALID=9999

KEY_FILE="${DIR}/${HOSTNAME}.key"
CONF_FILE="${DIR}/${HOSTNAME}.conf"
CSR_FILE="${DIR}/${HOSTNAME}.csr"
CRT_FILE="${DIR}/${HOSTNAME}.crt"

OPENSSL=openssl
if [[ -x /usr/local/opt/openssl/bin/openssl ]]; then
    # Use homebrew openssl
    OPENSSL=/usr/local/opt/openssl/bin/openssl
fi

cat <<EOF > "${CONF_FILE}"
[ req ]
distinguished_name  = req_distinguished_name
req_extensions = v3_req
 
[ req_distinguished_name ]
0.organizationName		= Organization Name (eg, company)

commonName      = Common Name (e.g. server FQDN or YOUR name)
commonName_max      = 64
 
[ v3_req ]
basicConstraints = critical,CA:true,pathlen:1
keyUsage = nonRepudiation, digitalSignature, keyEncipherment, keyCertSign
subjectAltName = @alt_names
 
[alt_names]
DNS.1 = localhost
DNS.2 = ${HOSTNAME}
EOF

$OPENSSL req -new -newkey "rsa:${KEY_LENGTH}" -keyout "${KEY_FILE}" "-${DIGEST}" -config "${CONF_FILE}" -out "${CRT_FILE}" -nodes -subj "/O=${ORGNAME}/CN=${HOSTNAME}" -x509 -extensions v3_req -days "${DAYS_VALID}"

rm "${CONF_FILE}"

$OPENSSL x509 -in "${CRT_FILE}" -text

mv "${CRT_FILE}" ./data/nginx/server.crt
mv "${KEY_FILE}" ./data/nginx/server.key

