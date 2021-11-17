#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../infra/ssl/fortifydemo_wildcard.pfx ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

kubectl delete -f dastcontroller.yaml --ignore-not-found=true
kubectl delete secret dastapisecrets --ignore-not-found=true
kubectl create secret generic dastapisecrets \
  --from-file=../infra/ssl/fortifydemo_wildcard.pfx \
  --from-literal=DAST_EDASTDB="$DAST_EDASTDB" \
  --from-literal=PWD_SSL_KEYSTORE="$PWD_SSL_KEYSTORE"  

kubectl apply -f dastcontroller.yaml
