#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../prereq/fortify.license ]; then
    echo "Please add your fortify.license to the prereq directory."
	exit 1
fi

if [ ! -f ../prereq/Fortify_SCA_and_Apps_20.2.2_linux_x64.run ]; then
    echo "Please add Fortify_SCA_and_Apps_20.2.2_linux_x64.run to the prereq directory."
	exit 1
fi

if [ ! -f ../infra/ssl/fortifydemo_wildcard.jks ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

echo "Copying Fortify SCA installer..."
rm -f fortify.license Fortify_SCA_and_Apps_20.2.2_linux_x64.run
cp ../prereq/fortify.license .
cp ../prereq/Fortify_SCA_and_Apps_20.2.2_linux_x64.run .
sudo docker build . -t localhost:32000/fortifyjenkins
if [ ! $? -eq 0 ]
then
  echo "Error building docker image."
  rm -f fortify.license Fortify_SCA_and_Apps_20.2.2_linux_x64.run
  exit 1
fi
rm -f fortify.license Fortify_SCA_and_Apps_20.2.2_linux_x64.run
sudo docker push localhost:32000/fortifyjenkins
if [ ! $? -eq 0 ]
then
  echo "Error pushing docker image."
  exit 1
fi

kubectl delete -f jenkins.yaml --ignore-not-found=true
kubectl delete secret jenkinssecrets --ignore-not-found=true


sudo rm -f client.properties
cat <<EOF >client.properties
client_auth_token=$PWD_SCSAST_CLIENT_TOKEN
javax.net.ssl.trustStore=/etc/truststore.jks
javax.net.ssl.trustStorePassword=$PWD_SSL_TRUSTSTORE
EOF
kubectl create secret generic jenkinssecrets \
  --from-file=../infra/ssl/cacerts \
  --from-file=../infra/ssl/fortifydemo_wildcard.jks \
  --from-file=../prereq/fortify.license \
  --from-file=./client.properties \
  --from-literal=JENKINS_OPTS="--httpPort=-1 --httpsPort=8443 --httpsKeyStore=/jenkinssecrets/fortifydemo_wildcard.jks --httpsKeyStorePassword=$PWD_SSL_KEYSTORE"
  
rm client.properties

kubectl apply -f jenkins.yaml

