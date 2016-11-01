#!/bin/sh

DIRNAME=$(dirname "$0")

openssl req -sha256 -new -key $DIRNAME/server_key.pem -out $DIRNAME/server.csr -subj "/CN=mercurio" -config $DIRNAME/server-openssl.cnf
openssl x509 -sha256 -req -in $DIRNAME/server.csr -CA $DIRNAME/ca_certificate.pem -CAkey $DIRNAME/ca_key.pem -CAcreateserial -CAserial $DIRNAME/ca.srl -out $DIRNAME/server_certificate.pem -days 3650 -extensions v3_req -extfile $DIRNAME/server-openssl.cnf

echo "Written new server CSR and certificate"