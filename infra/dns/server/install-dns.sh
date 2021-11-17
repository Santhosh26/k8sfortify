#!/bin/bash
sudo apt-get update
sudo apt-get install -y bind9 bind9utils bind9-doc bind9-host
sudo systemctl enable bind9

. ./update-dns.sh
