#!/bin/bash
if [ "$#" -ne 1 ]
then
  echo "Usage: set_hostname.sh <hostname>"
  exit 1
fi
sudo hostnamectl set-hostname $1
IP=`hostname -I | head -n1 | cut -d " " -f1`
sudo sed -i "/$IP/d" /etc/hosts
cat <<EOF | sudo tee -a /etc/hosts
$IP $1.fortifydemo.com $1
EOF
if [ -f /etc/cloud/cloud.cfg ]
then
  sudo sed -i -r 's/#{1,}?preserve_hostname:.*/preserve_hostname: true/g' /etc/cloud/cloud.cfg
fi
exec bash
