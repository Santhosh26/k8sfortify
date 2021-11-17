#!/bin/bash

source ../../prereq/readenv.sh ../../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

#
# CHECK PREREQUISITES
#
if ! command -v openssl &> /dev/null
then
    echo "openssl could not be found, please install before running this script"
    exit
fi
if ! command -v java &> /dev/null
then
    sudo apt-get install openjdk-8-jre -y
fi
if ! command -v keytool &> /dev/null
then
    echo "keytool could not be found, this should have come alongside the Java installation"
    exit
fi
if [ -z "$JAVA_TRUSTSTORE" ]
then
    echo "Variable JAVA_TRUSTSTORE wasn't set, will try to determine location of standard truststore."
	JAVA=`readlink -f $(which java)`
	JAVADIR=`dirname $JAVA`
	JAVA_TRUSTSTORE=$JAVADIR/../lib/security/cacerts
fi
if [ -f "$JAVA_TRUSTSTORE" ]
then
  echo "Found Java truststore at $JAVA_TRUSTSTORE."
else
  echo "Tried to find Java truststore at $JAVA_TRUSTSTORE, but this file didn't exist. Please set variable JAVA_TRUSTSTORE manually."
  exit
fi
if [ -z "$JAVA_TRUSTSTORE_PWD" ]
then
    echo "Variable JAVA_TRUSTSTORE_PWD wasn't set, assuming default 'changeit' password."
	JAVA_TRUSTSTORE_PWD=changeit
fi
keytool -list -keystore "$JAVA_TRUSTSTORE" -storepass "$JAVA_TRUSTSTORE_PWD" >/dev/null
if [ $? -eq 0 ]
then
  echo "JAVA_TRUSTSTORE_PWD is correct."
else
  echo "JAVA_TRUSTSTORE_PWD is incorrect, please set this to the correct password for $JAVA_TRUSTSTORE." 
  exit 1
fi

#
# START WITH AN EMPTY TMP DIR FOR CONFIGURATION, CSRs etc.
#
rm -rf ./tmp
mkdir ./tmp
touch ~/.rnd

#
# CREATING THE ROOT CERT
#
cat <<EOF > ./tmp/fortifydemo_ca.cnf
subjectKeyIdentifier=hash
basicConstraints=critical,CA:true
keyUsage=cRLSign,keyCertSign
nsCertType=sslCA
nsComment=Demo CA certificate generated using OpenSSL
EOF
openssl req -new -newkey rsa:2048 -nodes -keyout ./tmp/fortifydemo_ca.key \
    -out ./tmp/fortifydemo_ca.csr \
    -subj "/CN=Fortify Demo CA"
openssl x509 -req -in ./tmp/fortifydemo_ca.csr -extfile ./tmp/fortifydemo_ca.cnf \
    -signkey ./tmp/fortifydemo_ca.key -days 366 -out fortifydemo_ca.crt
openssl x509 -in fortifydemo_ca.crt -text -nocert

#
# CREATING THE WILDCARD SERVER CERT
#
cat <<EOF > ./tmp/fortifydemo_wildcard.cnf
subjectKeyIdentifier=hash
basicConstraints=critical,CA:false
keyUsage=nonRepudiation,digitalSignature,keyEncipherment,keyAgreement
extendedKeyUsage=serverAuth
subjectAltName=DNS:*.fortifydemo.com
nsCertType=server
nsComment="Demo server certificate generated using OpenSSL"
EOF
openssl req -new -newkey rsa:2048 -nodes -keyout fortifydemo_wildcard.key \
    -out ./tmp/fortifydemo_wildcard.csr \
    -subj "/CN=fortifydemo.com"
openssl x509 -req -in ./tmp/fortifydemo_wildcard.csr -extfile ./tmp/fortifydemo_wildcard.cnf \
    -CA fortifydemo_ca.crt -CAkey ./tmp/fortifydemo_ca.key -CAcreateserial \
    -days 365 -out fortifydemo_wildcard.crt
openssl x509 -in fortifydemo_wildcard.crt -text -nocert

#
# CREATING A JAVA TRUSTSTORE WITH THE ROOT CERTIFICATE, AND PASSWORD SET TO OUR FAVORITE DEMO PWD
#
cp "$JAVA_TRUSTSTORE" ./fortifydemo_truststore.jks
keytool -v -storepasswd -keystore fortifydemo_truststore.jks -storetype jks \
    -storepass "$JAVA_TRUSTSTORE_PWD" -new "$PWD_SSL_TRUSTSTORE" 
keytool -v -import -noprompt \
    -keystore fortifydemo_truststore.jks -storetype jks -storepass "$PWD_SSL_TRUSTSTORE" \
    -trustcacerts -alias fortifydemo_ca -file fortifydemo_ca.crt 

#
# CREATING A DROP-IN REPLACEMENT "cacerts" JAVA TRUSTSTORE WITH THE ROOT CERTIFICATE,
# AND PASSWORD SET TO THE DEFAULT "changeit"
#
cp "$JAVA_TRUSTSTORE" ./cacerts
keytool -v -storepasswd -keystore cacerts -storetype jks \
    -storepass "$JAVA_TRUSTSTORE_PWD" -new "changeit" 
keytool -v -import -noprompt \
    -keystore cacerts -storetype jks -storepass "changeit" \
    -trustcacerts -alias fortifydemo_ca -file fortifydemo_ca.crt 

#
# CREATING A PKCS12/PFX ARCHIVE FOR THE SERVER CERT, CONTAINING THE CHAIN AND THE PRIVATE KEY
#
openssl pkcs12 -inkey fortifydemo_wildcard.key -in fortifydemo_wildcard.crt \
	-CAfile fortifydemo_ca.crt -no-CApath -chain \
	-name "wildcard fortifydemo.com" -caname "Fortify Demo CA" \
	-CSP "Demo certificate generated using OpenSSL" \
	-LMK -descert -certpbe pbeWithSHA1And3-KeyTripleDES-CBC \
    -passout pass:"$PWD_SSL_KEYSTORE" -export -out fortifydemo_wildcard.pfx 

#
# CREATING A JAVA JKS KEYSTORE FOR THE SERVER CERT, CONTAINING THE CHAIN AND THE
# PRIVATE KEY, BY CONVERTING THE PFX
#
rm -f fortifydemo_wildcard.jks
keytool -v -importkeystore -noprompt \
   -srckeystore fortifydemo_wildcard.pfx -srcstoretype pkcs12 \
   -srcstorepass "$PWD_SSL_KEYSTORE"  \
   -destkeystore fortifydemo_wildcard.jks -deststoretype jks \
   -deststorepass "$PWD_SSL_KEYSTORE" 

#
# CLEANING UP
#
rm -rf ./tmp
rm -f *.srl

#
# FOR CONVENIENCE
#
cat <<EOF
=============================================================

Root certificate and wildcard server certificate have been created. The private key of the root certificate has been deleted to prevent
further certificates from being issued under this root.

To add the root certificate to the trust store of your system, the following commands can be used:

Windows: certutil -addstore root fortifydemo_ca.crt
Linux: sudo cp fortifydemo_ca.crt /usr/local/share/ca-certificates/;  sudo update-ca-certificates
Mac OS X: sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ./fortifydemo_ca.crt (didn't actually test this one as I don't have a Mac)

=============================================================
EOF
