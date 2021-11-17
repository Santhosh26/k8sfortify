#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../infra/ssl/fortifydemo_ca.crt ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

kubectl delete secret dastsensorsecrets --ignore-not-found=true
kubectl create secret generic dastsensorsecrets \
  --from-file=../infra/ssl/fortifydemo_ca.crt \
  --from-literal=DAST_TOKEN="$DAST_TOKEN"
kubectl get secret dastsensorsecrets --output=yaml

kubectl apply -f dastsensor.yaml
