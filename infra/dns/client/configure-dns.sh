#!/bin/bash

source ../../../prereq/readenv.sh ../../../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

cat <<EOF | sudo tee /etc/systemd/resolved.conf
[Resolve]
DNS=$DNS_UBUNTU01
Domains=fortifydemo.com
EOF
sudo systemctl restart systemd-resolved
