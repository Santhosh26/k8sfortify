#!/bin/bash

# Routing instruction to be pushed by OpenVPN to the client to route traffic into the server network
# This might just be a single line, or multiple subnets like in this example. Obtain this from your
# cloud provider configuration.
read -r -d '' OPENVPN_ROUTES <<EOF
push "route 172.31.0.0 255.255.240.0"
push "route 172.31.16.0 255.255.240.0"
push "route 172.31.32.0 255.255.240.0"
EOF
export OPENVPN_ROUTES

# Passwords; for a demo, it's convenient to set all passwords to the same value.
PWD_DEMO="S3cr3t&&"
export PWD_DATABASE=$PWD_DEMO
export PWD_SSL_KEYSTORE=$PWD_DEMO
export PWD_SSL_TRUSTSTORE=$PWD_DEMO
export PWD_LIM_ADMIN=$PWD_DEMO
export PWD_SCSAST_CLIENT_TOKEN=$PWD_DEMO
export PWD_SCSAST_WORKER_TOKEN=$PWD_DEMO
export PWD_SCSAST_SHARED_SECRET=$PWD_DEMO

# We need at a minimum two hosts, ubuntu01 and win01, and need to know their IP addresses.
export DNS_UBUNTU01=172.31.14.1
export DNS_WIN01=172.31.5.42
export DNS_FORWARD=172.31.0.2
# Additional DNS entries, e.g. for building a larger cluster.
read -r -d '' DNS_OPTIONAL <<EOF
ubuntu02    IN A    172.31.13.43
win02       IN A    172.31.21.37
EOF
export DNS_OPTIONAL

# For accessing Docker and pull our private images
export DOCKER_USERNAME='duser'
export DOCKER_PASSWORD='secretpwd'

# Replace the following example values from the values you find in the files written by the DAST config tool
export DAST_EDASTDB='y7i9VbpIPOhTgEbK6JKhGDfVcirSZisy6qK7P33MMsP3zbN0NCtBmGkuopfLo9GbT1u/gnNAGuPKxW7fa916KCU9R/QdauKIvfhk='
export DAST_TOKEN='4dGYNv3qaktOsiNH+aw=='

# These are used by the NexusIQ sync tool; they must be adapted to whatever is set in NexusIQ and SSC.
export NEXUSIQSYNC_IQSERVER_USER=admin
export NEXUSIQSYNC_IQSERVER_PWD=$PWD_DEMO
export NEXUSIQSYNC_SSC_TOKEN=M2NkZK231TctZ12MC00YzRhLTlmZjAtOTAwMDI3YmYyMmNm
