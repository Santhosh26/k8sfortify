#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../prereq/nexusiq.lic ]; then
    echo "Please add your nexusiq.lic to the prereq directory."
	exit 1
fi

if [ ! -f ../infra/ssl/fortifydemo_wildcard.jks ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

kubectl delete -f nexusiq.yaml --ignore-not-found=true
kubectl delete secret nexusiqsecrets --ignore-not-found=true

sudo rm -f config.yml
cat <<EOF >config.yml
baseUrl: https://nexusiq.fortifydemo.com
licenseFile: /nexusiqsecrets/nexusiq.lic
sonatypeWork: /sonatype-work
server:
  applicationConnectors:
  - type: https
    port: 8443
    keyStorePath: /nexusiqsecrets/fortifydemo_wildcard.jks
    keyStorePassword: '$PWD_SSL_KEYSTORE'
  adminConnectors:
  - type: https
    port: 8444
    keyStorePath: /nexusiqsecrets/fortifydemo_wildcard.jks
    keyStorePassword: '$PWD_SSL_KEYSTORE'
  requestLog:
    appenders:
    - type: file
      currentLogFilename: "/var/log/nexus-iq-server/request.log"
      archivedLogFilenamePattern: "/var/log/nexus-iq-server/request-%d.log.gz"
      archivedFileCount: 5
logging:
  level: DEBUG
  loggers:
    com.sonatype.insight.scan: INFO
    eu.medsea.mimeutil.MimeUtil2: INFO
    org.apache.http: INFO
    org.apache.http.wire: ERROR
    org.eclipse.birt.report.engine.layout.pdf.font.FontConfigReader: WARN
    org.eclipse.jetty: INFO
    org.apache.shiro.web.filter.authc.BasicHttpAuthenticationFilter: INFO
    com.sonatype.insight.audit:
      appenders:
      - type: file
        currentLogFilename: "/var/log/nexus-iq-server/audit.log"
        archivedLogFilenamePattern: "/var/log/nexus-iq-server/audit-%d.log.gz"
        archivedFileCount: 50
  appenders:
  - type: console
    threshold: INFO
    logFormat: "%d{'yyyy-MM-dd HH:mm:ss,SSSZ'} %level [%thread] %X{username} %logger
      - %msg%n"
  - type: file
    threshold: ALL
    currentLogFilename: "/var/log/nexus-iq-server/clm-server.log"
    archivedLogFilenamePattern: "/var/log/nexus-iq-server/clm-server-%d.log.gz"
    logFormat: "%d{'yyyy-MM-dd HH:mm:ss,SSSZ'} %level [%thread] %X{username} %logger
      - %msg%n"
    archivedFileCount: 5
createSampleData: true
EOF

kubectl create secret generic nexusiqsecrets \
  --from-file=../prereq/nexusiq.lic \
  --from-file=../infra/ssl/fortifydemo_wildcard.jks \
  --from-file=./config.yml
rm config.yml

kubectl apply -f nexusiq.yaml
