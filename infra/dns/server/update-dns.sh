#!/bin/bash

source ../../../prereq/readenv.sh ../../../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

SERIAL=`date +%Y%m%d%S`
cat <<EOF > ./fortifydemo.com.zone
\$TTL 86400

@ IN SOA fortifydemo.com root.fortifydemo.com (
  $SERIAL ; serial
  3600        ; refresh (1 hour)
  900         ; retry (15 minutes)
  604800      ; expire (1 week)
  86400       ; minimum (1 day) 
)

@           IN NS   ubuntu01
ubuntu01    IN A    $DNS_UBUNTU01
win01       IN A    $DNS_WIN01
$DNS_OPTIONAL
sql         IN A    10.96.96.1
ssc         IN A    10.96.96.2
lim         IN A    10.96.96.3
edast       IN A    10.96.96.4
scsast      IN A    10.96.96.5
jenkins     IN A    10.96.96.6
nexusiq     IN A    10.96.96.7
EOF

sudo /usr/sbin/named-checkzone fortifydemo.com ./fortifydemo.com.zone
if [ ! $? -eq 0 ]
then
  echo "There is a problem with the zone file." 
  exit 1
fi

cat <<EOF > ./named.conf.options
options {
  directory "/var/cache/bind";
  listen-on port 53 { any; };
  allow-query       { any; };
  allow-query-cache { any; };
  allow-recursion   { any; };
  forwarders        { $DNS_FORWARD; 8.8.8.8; 8.8.4.4; };    # Our AWS DNS + google backup
  recursion yes;
  dnssec-enable yes;           #  https://serverfault.com/questions/717775/bind-server-has-tons-of-no-valid-rrsig-errors
  dnssec-validation yes;
  auth-nxdomain no;    # conform to RFC1035
};
EOF

cat <<EOF > ./named.conf.local
zone "fortifydemo.com" IN {
  type master;
  file "/etc/bind/fortifydemo.com.zone";
};
EOF


sudo mv ./named.conf.options ./named.conf.local ./fortifydemo.com.zone /etc/bind

sudo systemctl restart bind9
