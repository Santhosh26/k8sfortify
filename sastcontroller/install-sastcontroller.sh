#!/bin/bash

source ../prereq/readenv.sh ../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

if [ ! -f ../prereq/Fortify_ScanCentral_Controller_20.2.0_x64.zip ]; then
    echo "Please add Fortify_ScanCentral_Controller_20.2.0_x64.zip to the prereq directory."
	exit 1
fi

if [ ! -f ../infra/ssl/fortifydemo_wildcard.jks ]; then
    echo "Please ensure SSL certificates have been created."
	exit 1
fi

rm -f Fortify_ScanCentral_Controller_20.2.0_x64.zip
cp ../prereq/Fortify_ScanCentral_Controller_20.2.0_x64.zip .
sudo docker build . -t localhost:32000/sastcontroller
if [ ! $? -eq 0 ]
then
  echo "Error building docker image."
  rm -f Fortify_ScanCentral_Controller_20.2.0_x64.zip
  exit 1
fi
rm -f Fortify_ScanCentral_Controller_20.2.0_x64.zip
sudo docker push localhost:32000/sastcontroller
if [ ! $? -eq 0 ]
then
  echo "Error pushing docker image."
  exit 1
fi

kubectl delete -f sastcontroller.yaml --ignore-not-found=true

kubectl delete secret sastctrlsecrets --ignore-not-found=true

sudo rm -f config.properties server.xml
cat <<EOF >config.properties
db_dir=/pv/cloudCtrlDb
worker_auth_token=$PWD_SCSAST_WORKER_TOKEN
client_auth_token=$PWD_SCSAST_CLIENT_TOKEN
allow_insecure_clients_with_empty_token=false
job_file_dir=/pv/jobFiles
max_upload_size=4096
smtp_host=localhost
smtp_port=25
from_email=changeme@yourcompanyname.com
job_expiry_delay=168
worker_stale_delay=60
worker_inactive_delay=60
# Setting this to a really low value to keep our cloud demo a bit clean (it's hours)
worker_expiry_delay=4
cleanup_period=60
ssc_url=https://ssc.fortifydemo.com
ssc_lockdown_mode=false
ssc_scancentral_ctrl_secret=$PWD_SCSAST_SHARED_SECRET
pool_mapping_mode=disabled
this_url=https://scsast.fortifydemo.com/scancentral-ctrl
ssc_remote_ip=10.244.0.0/16
ssc_remote_ip_header=
ssc_remote_ip_trusted_proxies_range=
client_zip_location=\${catalina.base}/client/scancentral.zip
client_auto_update=false
fail_job_if_uptoken_invalid=false
EOF

cat <<EOF >server.xml
<?xml version="1.0" encoding="UTF-8"?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />
  <Service name="Catalina">
    <Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
               maxThreads="150" SSLEnabled="true">
        <SSLHostConfig>
            <Certificate certificateKeystoreFile="/sastctrlsecrets/fortifydemo_wildcard.jks"
			             certificateKeystorePassword="$(xmlEscape $PWD_SSL_KEYSTORE)"
						 certificateKeystoreType="JKS"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>
    <Engine name="Catalina" defaultHost="localhost">
      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />
      </Host>
    </Engine>
  </Service>
</Server>
EOF

kubectl create secret generic sastctrlsecrets \
  --from-file=../infra/ssl/cacerts \
  --from-file=./config.properties \
  --from-file=./server.xml \
  --from-file=../infra/ssl/fortifydemo_wildcard.jks
rm -f worker.properties server.xml


kubectl apply -f sastcontroller.yaml
