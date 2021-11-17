#!/bin/bash

if [ ! "`hostname`" == "ubuntu01" ]; 
then 
  echo "Hostname should be set to ubuntu01 before starting this script, because we will"
  echo "select this node explicitly for several Kubernetes workloads."; 
  exit 1
fi

#
# INSTALL BASICS NEEDED TO AUTOMATE THE INSTALLATION
#
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

#
# INSTALL DOCKER
#
#Swap is already disabled on AWS. If needed to disable it in other environments:
#sudo swapoff -a
#sudo vi  /etc/fstab
#sudo systemctl --all --type swap
#sudo systemctl mask swap.img.swap
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce=5:18.09.9~3-0~ubuntu-bionic docker-ce-cli=5:18.09.9~3-0~ubuntu-bionic containerd.io
    
sudo usermod -aG docker $USER

curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
sudo apt-get update

#
# INSTALL KUBERNETES
#
sudo apt-get install -y kubelet=1.18.15-00 kubeadm=1.18.15-00 kubectl=1.18.15-00
sudo apt-mark hold kubelet kubeadm kubectl
sudo kubeadm config images pull
sudo kubeadm init --pod-network-cidr=10.244.0.0/16   # (prepping for Flannel)
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#
# INSTALL HELM
#
curl https://baltocdn.com/helm/signing.asc | sudo apt-key add -
sudo apt-get install apt-transport-https --yes
echo "deb https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
