#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../prereq/fortify.license ]; then
    echo "Please add your fortify.license to the prereq directory."
	exit 1
fi

if [ ! -f ../prereq/ssc-1.0.149+20.2.0.0149.tgz ]; then
    echo "Please add Helm chart ssc-1.0.149+20.2.0.0149.tgz to the prereq directory."
	exit 1
fi

if [ ! -f ../prereq/create-tables.sql ]; then
    echo "Please add the create-tables.sql for SSC on MS SQL server to the prereq directory."
	exit 1
fi

if [ ! -f ../infra/ssl/fortifydemo_wildcard.jks ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

helm uninstall ssc
kubectl delete -f ssc_pv.yaml --ignore-not-found=true
kubectl delete secret sscsecrets --ignore-not-found=true

sudo rm -f ssc.autoconfig.yaml
cat <<EOF >ssc.autoconfig.yaml
appProperties:
  host.validation: false

datasourceProperties:
  db.username: 'sa'
  db.password: '$PWD_DATABASE'
  db.driver.class: com.microsoft.sqlserver.jdbc.SQLServerDriver
  db.dialect: com.fortify.manager.util.hibernate.SQLServerDialect
  db.like.specialCharacters: '%_{'
  jdbc.url: 'jdbc:sqlserver://10.96.96.1:1433;database=ssc;sendStringParametersAsUnicode=false'
EOF

kubectl create secret generic sscsecrets \
  --from-file=../prereq/fortify.license \
  --from-file=./ssc.autoconfig.yaml \
  --from-file=../infra/ssl/fortifydemo_wildcard.jks \
  --from-file=../infra/ssl/fortifydemo_truststore.jks \
  --from-literal=keystore.pwd="$(xmlEscape $PWD_SSL_KEYSTORE)" \
  --from-literal=truststore.pwd="$PWD_SSL_TRUSTSTORE"

rm -f ssc.autoconfig.yaml

/opt/mssql-tools/bin/sqlcmd -S 10.96.96.1 -U sa -P $PWD_DATABASE -i recreatedb.sql

kubectl apply -f ssc_pv.yaml


helm install ssc ../prereq/ssc-1.0.149+20.2.0.0149.tgz -f ssc-values.yaml
