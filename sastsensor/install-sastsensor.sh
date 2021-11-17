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

if [ ! -f ../infra/ssl/cacerts ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

echo "Copying Fortify SCA installer..."
rm -f fortify.license Fortify_SCA_and_Apps_20.2.2_linux_x64.run
cp ../prereq/fortify.license .
cp ../prereq/Fortify_SCA_and_Apps_20.2.2_linux_x64.run .
sudo docker build . -t localhost:32000/sastsensor
if [ ! $? -eq 0 ]
then
  echo "Error building docker image."
  rm -f fortify.license Fortify_SCA_and_Apps_20.2.2_linux_x64.run
  exit 1
fi
rm -f fortify.license Fortify_SCA_and_Apps_20.2.2_linux_x64.run
sudo docker push localhost:32000/sastsensor
if [ ! $? -eq 0 ]
then
  echo "Error pushing docker image."
  exit 1
fi

kubectl delete -f sastsensor.yaml --ignore-not-found=true

kubectl delete secret sastsensorsecrets --ignore-not-found=true
sudo rm -f worker.properties
cat <<EOF >worker.properties
worker_auth_token=$PWD_SCSAST_WORKER_TOKEN
EOF
kubectl create secret generic sastsensorsecrets \
  --from-file=../infra/ssl/cacerts \
  --from-file=../prereq/fortify.license \
  --from-file=./worker.properties \
  --from-file=./scancentral.properties
rm -f worker.properties

kubectl apply -f sastsensor.yaml
