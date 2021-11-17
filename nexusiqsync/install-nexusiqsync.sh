#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../prereq/SonatypeFortifyIntegration-20.1.20200914.jar ]; then
    echo "Please add SonatypeFortifyIntegration-20.1.20200914.jar to the prereq directory."
	exit 1
fi

rm -f SonatypeFortifyIntegration-20.1.20200914.jar
cp ../prereq/SonatypeFortifyIntegration-20.1.20200914.jar .
sudo docker build . -t localhost:32000/nexusiqsync
if [ ! $? -eq 0 ]
then
  echo "Error building docker image."
  rm -f SonatypeFortifyIntegration-20.1.20200914.jar
  exit 1
fi
rm -f SonatypeFortifyIntegration-20.1.20200914.jar
sudo docker push localhost:32000/nexusiqsync
if [ ! $? -eq 0 ]
then
  echo "Error pushing docker image."
  exit 1
fi

kubectl delete -f nexusiqsync.yaml --ignore-not-found=true

kubectl delete secret nexusiqsyncsecrets --ignore-not-found=true

sudo rm -f iqapplication.properties
cat <<EOF >iqapplication.properties
server.port=8182
iqserver.url=https://nexusiq.fortifydemo.com
iqserver.username=$NEXUSIQSYNC_IQSERVER_USER
iqserver.password=$NEXUSIQSYNC_IQSERVER_PWD
sscserver.url=https://ssc.fortifydemo.com
sscserver.token=$NEXUSIQSYNC_SSC_TOKEN
loadfile.location=/work
mapping.file=/work/mapping.json
update.mapping.file=true
iq.report.type=vulnerabilities
logfile.location=/work/Servicelog.log
logLevel=warn
#logLevel=info
scheduling.job.cron=0/30 * * * * ?
KillProcess=false
EOF
kubectl create secret generic nexusiqsyncsecrets \
  --from-file=./iqapplication.properties \
  --from-file=../infra/ssl/cacerts
rm iqapplication.properties

kubectl apply -f nexusiqsync.yaml
