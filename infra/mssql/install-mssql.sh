#!/bin/bash

source ../../prereq/readenv.sh ../../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

#
# DEPLOY MSSQL
#
kubectl delete -f mssql.yaml --ignore-not-found=true
kubectl delete secret mssql --ignore-not-found=true
kubectl create secret generic mssql \
  --from-literal=SA_PASSWORD=$PWD_DATABASE
kubectl apply -f mssql.yaml

#
# INSTALL THE CLIENT TOOLS LOCALLY FOR CONVENIENCE
#
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt-get update
sudo apt-get install mssql-tools unixodbc-dev -y
sudo rm -f /usr/local/bin/bcp
sudo rm -f /usr/local/bin/sqlcmd
sudo ln -s /opt/mssql-tools/bin/bcp /usr/local/bin
sudo ln -s /opt/mssql-tools/bin/sqlcmd /usr/local/bin
