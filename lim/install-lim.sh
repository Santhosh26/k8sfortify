#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../infra/ssl/fortifydemo_wildcard.jks ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

kubectl delete -f lim.yaml --ignore-not-found=true

kubectl delete secret limsecrets --ignore-not-found=true
kubectl create secret generic limsecrets \
  --from-file=../infra/ssl/fortifydemo_wildcard.pfx \
  --from-literal=certpassword="$PWD_SSL_TRUSTSTORE" \
  --from-literal=LimAdminPassword="$PWD_LIM_ADMIN"

kubectl apply -f lim.yaml
