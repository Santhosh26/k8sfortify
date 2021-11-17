#!/bin/bash

source ../../../prereq/readenv.sh ../../../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

#
# UNTAINT THE MASTER
#
kubectl taint nodes --all node-role.kubernetes.io/master-

#
# ADD NETWORKING
#
kubectl apply -f kube-flannel.yaml
kubectl apply -f win-flannel-overlay.yaml
kubectl apply -f win-kube-proxy.yaml

#
# DEPLOY A REGISTRY
#
kubectl apply -f registry.yaml

#
# STORE DOCKER REGISTRY CREDENTIALS
#
kubectl delete secret regcred --ignore-not-found=true
kubectl create secret docker-registry regcred \
   --docker-server="https://index.docker.io/v1/" \
   --docker-username=$DOCKER_USERNAME \
   --docker-password=$DOCKER_PASSWORD
kubectl get secret regcred --output=yaml

#
# ALSO LOGIN ON DOCKER LEVEL FOR CONVENIENCE
#
sudo docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
