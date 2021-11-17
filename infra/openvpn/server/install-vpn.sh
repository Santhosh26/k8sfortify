#!/bin/bash

source ../../../prereq/readenv.sh ../../../prereq/setenv.sh
if [ ! $? -eq 0 ]; then echo "couldn't execute readenv.sh"; exit 1; fi

for file in dh2048.pem k8svpn_ca.crt k8svpn_server.crt k8svpn_server.key
do
  if [ ! -f $file ]
  then
    echo "$file missing; you probably need to run recreate-crypto.sh first"
	exit 1
  fi
done


sudo apt-get update

# Enable routing
#  (thanks to https://stackoverflow.com/questions/44018705/modify-config-files-with-sed-in-bash)
sudo sed -i -r 's/#{1,}?net.ipv4.ip_forward ?= ?(0|1)/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_forward=1
cat <<EOF | sudo tee /etc/rc.local
#!/bin/sh
/sbin/iptables -I FORWARD 1 -s 192.168.60.0/24 -j ACCEPT
/sbin/iptables -t nat -I POSTROUTING 1 -s 192.168.60.0/24 -d 0.0.0.0/0 -j MASQUERADE
exit 0
EOF
sudo chmod +x /etc/rc.local
sudo /etc/rc.local

# Install OpenVPN
sudo apt-get install -y openvpn

sudo rm -rf ccd k8svpn_server.conf
mkdir -p ccd
touch ccd/k8svpn_client_srv
echo "$OPENVPN_ROUTES" | tee >ccd/k8svpn_client_pc

cat <<EOF >k8svpn_server.conf
proto tcp
port 443
dev tun
ca    k8svpn_ca.crt
cert  k8svpn_server.crt
key   k8svpn_server.key
dh    dh2048.pem
client-config-dir ccd
duplicate-cn
topology  subnet
server    192.168.60.0 255.255.255.0        # OpenVPN network, server will be .1, first client .2
push "route 10.96.0.0 255.240.0.0"          # Kubernetes Cluster IPs
push "dhcp-option DNS $DNS_UBUNTU01"         # This must be the AWS internal IP address of the server 
push "dhcp-option DOMAIN fortifydemo.com"
push "block-outside-dns" 
keepalive 10 120
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log         /var/log/openvpn/openvpn.log
verb 4
mute 20
EOF

sudo cp -r ccd dh2048.pem k8svpn_ca.crt k8svpn_server.crt k8svpn_server.key k8svpn_server.conf /etc/openvpn
sudo systemctl enable openvpn@k8svpn_server.service
sudo systemctl restart openvpn@k8svpn_server
