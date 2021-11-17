#!/bin/bash

#
# CHECK PREREQUISITES
#
if ! command -v openssl &> /dev/null
then
    echo "openssl could not be found, please install before running this script"
    exit
fi

#
# START WITH AN EMPTY TMP DIR FOR CONFIGURATION, CSRs etc.
#
rm -rf ./tmp
mkdir ./tmp
touch ~/.rnd

#
# CREATING DIFFIE-HELLMAN PARAMS
#
openssl dhparam -out ./server/dh2048.pem 2048

#
# CREATING THE ROOT CERT
#
cat <<EOF > ./tmp/k8svpn_ca.cnf
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints=critical,CA:true,pathlen:0
keyUsage=cRLSign,keyCertSign
nsCertType=sslCA
nsComment="CA certificate for use with OpenVPN generated using OpenSSL"
EOF
openssl req -new -newkey rsa:2048 -nodes -keyout ./tmp/k8svpn_ca.key \
    -out ./tmp/k8svpn_ca.csr \
    -subj "/CN=Fortify Demo K8s VPN CA"
openssl x509 -req -in ./tmp/k8svpn_ca.csr -extfile ./tmp/k8svpn_ca.cnf \
    -signkey ./tmp/k8svpn_ca.key -days 366 -out ./server/k8svpn_ca.crt
openssl x509 -in ./server/k8svpn_ca.crt -text -nocert
cp ./server/k8svpn_ca.crt ./client_pc
cp ./server/k8svpn_ca.crt ./client_srv

#
# CREATING THE SERVER CERT
#
cat <<EOF > ./tmp/k8svpn_server.cnf
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
basicConstraints=critical,CA:false
keyUsage=nonRepudiation,digitalSignature,keyEncipherment,keyAgreement
extendedKeyUsage=serverAuth
nsCertType=server
nsComment="Server certificate for use with OpenVPN generated using OpenSSL"
EOF
openssl req -new -newkey rsa:2048 -nodes -keyout ./server/k8svpn_server.key \
	-out ./tmp/k8svpn_server.csr \
	-subj "/CN=k8svpn_server"
openssl x509 -req -in ./tmp/k8svpn_server.csr -extfile ./tmp/k8svpn_server.cnf \
	-CA ./server/k8svpn_ca.crt -CAkey ./tmp/k8svpn_ca.key -CAcreateserial \
	-days 365 -out ./server/k8svpn_server.crt
openssl x509 -in ./server/k8svpn_server.crt -text -nocert

#
# CREATING BOTH CLIENT CERTS
#
cat <<EOF > ./tmp/k8svpn_client.cnf
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid,issuer
basicConstraints=critical,CA:false
keyUsage=digitalSignature,keyEncipherment,keyAgreement,dataEncipherment
extendedKeyUsage=clientAuth
nsCertType=client
nsComment="Client certificate for use with OpenVPN generated using OpenSSL"
EOF
for CERT in client_pc client_srv
do
    openssl req -new -newkey rsa:2048 -nodes -keyout ./$CERT/k8svpn_$CERT.key \
        -out ./tmp/k8svpn_$CERT.csr \
        -subj "/CN=k8svpn_$CERT"
    openssl x509 -req -in ./tmp/k8svpn_$CERT.csr -extfile ./tmp/k8svpn_client.cnf \
        -CA ./server/k8svpn_ca.crt -CAkey ./tmp/k8svpn_ca.key -CAcreateserial \
        -days 365 -out ./$CERT/k8svpn_$CERT.crt
    openssl x509 -in ./$CERT/k8svpn_$CERT.crt -text -nocert
done

#
# CLEANUP
#
rm -rf ./tmp 
rm -f ./server/k8svpn_ca.srl
