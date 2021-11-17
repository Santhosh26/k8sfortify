# k8sfortifylab

This project provides a collection of scripts and configuration files that makes it easy to install a complete, integrated Fortify environment (ScanCentral SAST, ScanCentral DAST, Sonatype, Jenkins) on a mixed Ubuntu/Windows Kubernetes cluster. Using these scripts, this entire setup, starting from scratch, can be completed in less than two hours.

In this document, we provide 
1. an overview of the technology, which is useful to understand the set-up, and then 
2. concrete installation steps to build this environment yourself.

# Technology overview

### Kubernetes: general
So why run everything Fortify on Kubernetes? There are many reasons:
* Obviously, it's the only way to demo the SSC Helm chart deployment.
* It's cool.
* Makes it really easy to scale out both SAST and DAST sensors.
* Enables many configuration steps to be coded rather than described, leading to a more repeatable setup.
* Provides an abstraction layer (such as a cluster IP network) that can be the same regardless of the underlying infrastructure, again leading to a more repeatable setup.
* Once SSC is already in Kubernetes, it is actually convenient to do everything there.

Note that our Kubernetes cluster has to be a hybrid of Linux and Windows. Our DAST has Windows containers, which require a Windows host. On the other hand, Kubernetes clusters cannot be Windows-only.

>Side note: apparently, [it is possible](https://devblogs.microsoft.com/premier-developer/mixing-windows-and-linux-containers-with-docker-compose/) to mix Linux and Windows containers on a single Windows host, relying on Docker experimental features; I didn't explore this route.

To obtain a Kubernetes cluster, there are two main options: obtain it as-a-service from a cloud provider ([Amazon EKS](https://aws.amazon.com/eks), [Google GKE](https://cloud.google.com/kubernetes-engine), [Azure AKS](https://docs.microsoft.com/azure/aks)), or build your own. To get a Kubernetes cluster in the cloud for production usage, organizations should probably choose the first option. However, for our demo purposes, this would have a few disadvantages: it's more tightly bound to the specific cloud provider, less flexible, and more expensive. Therefore, we'll build our own Kubernetes cluster on virtual machines. We'll use [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) to create the cluster and [flannel](https://github.com/flannel-io/flannel#flannel) as our network fabric. Several other choices are possible (e.g. [MicroK8s](https://microk8s.io/), [Calico](https://www.projectcalico.org/)), but this one is tried and tested in this mixed Windows/Linux configuration.

The following combination of versions of the various technologies provides a compatible set that works for this demo:
- Ubuntu 18.04
- Windows Server 2019
- Docker 18.09
- Kubernetes 1.18.15

> Note the following consequences: in AWS, the image "Microsoft Windows Server 2019 Base with Containers" will provide Docker 19, which won't work. Therefore, when using AWS, choose plain "Microsoft Windows Server 2019 Base" and install Docker manually. Make sure to install Docker using the provided scripts rather than manually installing "Docker Desktop", which is not what we need.

### Kubernetes: specific techniques we're using

_ClusterIP_: Kubernetes will spin up pods and provide them with an IP address in the pod network (in our setup `10.244.0.0/16`). While you technically can contact these IP addresses, that is practically useless because these IP addresses are allocated dynamically (the 3rd octet of the address corresponding to the node). To make pods addressable, we define Kubernetes 'services'. Multiple service types exists. We'll use 'ClusterIP' services, which allows us to statically assign an IP address in the virtual service network (in our setup `10.96.0.0/12`, which is the default for kubeadm). Practically, we'll use `10.96.96.1`, `10.96.96.2`, etc. as a convention. We can assign hostnames to these addresses via our DNS; more on that below.

_Custom Images_: The level of Kubernetes support of the applications we're installing varies. In the case of SSC, we have full out-of-the-box Kubernetes support using Helm, so essentially we're just configuring stuff. In the cases of DAST, Nexus IQ Server, Jenkins, we have standard Docker images but we'll write Kubernetes configuration ourself without Helm. For the SAST components and for Sonatype integration service, we'll create our own Docker images. To make the latter work and make these images findable by Kubernetes across nodes, we install a repository services in Kubernetes and push our images to that repository.
> Caveat: the Docker images and Kubernetes configuration in our repository are good enough for a demo, but would require further refinement for production usage, especially in the area of resource management.

_Persistent Volumes_: In Kubernetes, Pods are ephemeral and anything you need to store persistently has to be on a [persistent volume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/). Kubernetes has a useful abstraction here: Pods do a persistence volume claim (pvc) that Kubernetes will try to satisfy by binding it to an actual persistent volume (pv). This allows for dynamic provisioning of pv's and abstracts away the concrete type of the pv from the application. For our demo, we'll greatly simplify this mechanism: instead of using auto-provisioning, we create pvc and pv in pairs linked to one another. The pv's simply map to a directory on the host. The components that do need persistent storage (this is not true for the sensors) will be bound to a specific host, `ubuntu01` or `win01`, where the pv lives.

_Secrets_: As a matter of good practice, neither Docker images nor Kubernetes config files should contain secrets. Instead, we create Kubernetes [secret](https://kubernetes.io/docs/concepts/configuration/secret/) objects. These can be used in two ways: they can be referred to in a Kubernetes config file and they can be mounted in a Kubernetes container. Kubernetes has a similar mechanism for configuration that should not be hardcoded but nevertheless isn't secret ([configMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)), however, for simplicity, we'll use the secrets mechanism for everything.

### SSL

We'll configure proper SSL on all our servers. There are a few reasons for doing so: it is required by the SSC Helm deployment, and it is required by OpenVPN, so we can't get rid of SSL completely. So then, why not do it everywhere? Also, it simply looks a lot nicer in a security demo to have the padlock icon in a browser instead of the "insecure" warning, even though that doesn't have anything to do with appsec per se.

The SSL on the level of our web servers is conceptually separate from the one we need for our OpenVPN connections, so we'll model that as two 'mini-PKIs', each with there own root certificate.

For SSL on the web servers, we have a very simple structure:
* a trusted root certificate (`CN=Fortify Demo CA`)
* a wildcard certificate signed by the root (`CN=fortifydemo.com, subjectAltName=DNS:*.fortifydemo.com`) that we can use everywhere.

The script `~/k8sfortifylab/infra/ssl/recreate-crypto.sh` generates these certificates and then converts them to a variety of formats needed in the rest of the installation (JKS keystore, JKS truststore, pfx).

To support OpenVPN, we have the following set of certificates:
* a trusted root certifcate (`CN=Fortify Demo K8s VPN CA`)
* a server certificate (`CN=k8svpn_server`)
* a client certificate for workstations (`CN=k8svpn_client_pc`)
* a client certificate for other servers that are not kube nodes (`CN=k8svpn_client_srv`).

The last one is actually not used in the demo as we describe it here, but you might want to use it in your own extensions of this demo; more on that under OpenVPN below.

The script `~/k8sfortifylab/infra/openvpn/recreate-crypto.sh` creates those certificates.

Both scripts will delete the ca private key at the end, for security reasons.

### DNS
We want to address hosts by their names (e.g. https://ssc.fortifydemo.com) rather than IP addresses. Doing this using hostfiles is not practical on a larger demo like this. There, to make this work, we'll configure DNS as follows:
- Our main server `ubuntu01` will be configured as an authoritative DNS server for `fortifydemo.com`, using [BIND](https://www.isc.org/bind/).
- This DNS server will forward requests for any other name to the normal DNS server provided by the (cloud) provider.
- Our nodes `ubuntu01`, `win01` and potentially more will be configured to use `ubuntu01` for DNS resolution.
- We'll push this DNS server to our workstation as well using OpenVPN; more on that below.
- Our Kubernetes pods will resolve hosts to the Kubernetes-internal DNS server ([CoreDNS](https://coredns.io/)). This will forward to the DNS server configured on the host, so our names are accessible to Kubernetes pods as well.

### OpenVPN
On a networking level, the demo set-up has a few challenges:
- By default, public IP addresses on Amazon and other cloude providers are variable (they are stable during an immediate restart, but not when you stop and later start a machine). Fixing them is possible at a price and with certain limits. It is not a very scalable solution for all our demos. 
- The Kubernetes/Flannel networks (the pod network and service network) are not accessible outside the Kubernetes cluster. Also, while Amazon allows some configuration of routing in the VPC, you actually can't get it to route arbitrary private IP ranges over the VPC.

We're using [OpenVPN](https://community.openvpn.net/openvpn) to work around this. The basic idea is that we'll set-up a VPN between the workstation and `ubuntu01`. That's the only public IP address we care about. You may keep that fixed or easily set it when starting the OpenVPN connection. Over this VPN connection:
- We'll route traffic to the fixed, internal IP addresses of the servers. (In my case, `172.31.0.0/20` and two other ranges.)
- We'll route traffic to the Kubernetes service network `10.96.0.0/12`.
- We'll push DNS configuration so the client uses `ubuntu01` for DNS resolution.

Although it's not part of this described set-up, there could be cases where you want another server (already in the server network) to be able to contact the applications running on Kubernetes, without actually being part of the Kubernetes cluster itself. Or, you might use local servers in your own network rather than a cloud provider. In that case, you'd still need a VPN connection to route `10.96.0.0/12`, but you wouldn't need it for the other addresses. The OpenVPN profile k8svpn_client_srv has been configured to do exactly that.

### Installation scripts
The vast majority of the installation takes place on the central Linux server `ubuntu01` and is done using prewritten bash scripts, stored in the Gitlab repository. The material in Gitlab is free of secrets, environment-specific items and software assets. `.gitignore` files have been placed to prevent such material from accidentially being pushed to the repository.

The `prereq` directory needs to be filled with prequisites like software, license keys etc. (details below). It also needs to have a file `setenv.sh` that will be the place to store environment-specific variables (again, details below).

A very common case in our scripts is that we need to create a Kubernetes secret containing certain files, with these files also containing secrets or environment-specific things. We heavily use the [heredoc](https://linuxize.com/post/bash-heredoc/) syntax for this, writing temporary files with dynamically provided values, including them in the secret, then deleting them again.

# Installation steps

## Requirements

To complete the installation, you'll need the following:

* Items to be uploaded to the demo environment:
    * `create-tables.sql` (for MS SQL Server; from SSC 20.2 distribution)
    * `ssc-1.0.149+20.2.0.0149.tgz` (from SSC 20.2 distribution)
    * `fortify.license`
    * `nexusiq.lic`  (any NexusIQ license, just rename it like this)
    * `Fortify_SCA_and_Apps_20.2.2_linux_x64.run`
    * `Fortify_ScanCentral_Controller_20.2.0_x64.zip`
    * `SonatypeFortifyIntegration-20.1.20200914.jar` (from SonatypeFortifyBundle-20.1.zip)
* Items needed locally on your workstation:
    * `ScanCentral DAST - Config Tool Setup 20.2.312.exe`
    * Some SSH tool, I prefer [Bitvise SSH Client](https://www.bitvise.com/ssh-client)
    * [OpenVPN Connect](https://openvpn.net/client-connect-vpn-for-windows/)
    * `sonatype-plugin-20.1.20200914.jar` (from SonatypeFortifyBundle-20.1.zip)
* Other:
    * access to the [k8sfortifylab gitlab repository](https://gitlab.com/fransvanbuul/k8sfortifylab), which you probably already have when you're reading this (you might consider "forking" it so you can easily save you're own additions, but that's not required)
    * access to the [Fortify organization on Dockerhub](https://hub.docker.com/orgs/fortifydocker/repositories) so you can access the private repos like [fortifydocker/ssc-webapp](https://hub.docker.com/repository/docker/fortifydocker/ssc-webapp)
    * a WebInspect concurrent license key.

## Hardware

The project has been developed running on AWS virtual machines, but nothing is AWS-specific and any other way of providing (virtual) machines would work as well.

We need at least two machines: one Ubuntu machine (`ubuntu01`) and one Windows machines (`win01`). These names are fixed in the scripts. `ubuntu01` will be the Kubernetes master and will be installed first. `win01` is required because the ScanCentral DAST containers are Windows containers and can't run on a Linux host. Additional machines with arbitrary names can be added later to scale out the cluster.

You need to ensure that the virtual machines can freely communicate with each other, and that you can reach them from your workstation of course.
> Example: In my AWS environment, the VPC has 3 subnets (`172.31.0.0/20`, `172.31.16.0/20`, `172.31.32.0/20`). Therefore, I created a security group that has 4 inbound rules to allow all traffic from these 3 subnets + all traffic from my office, and selected this for my instances.

The demo has been tested on the following machines on AWS:
* `ubuntu01`: Ubuntu 18.04, t3.xlarge (4 cores, 16 GB), 60G gp3 storage
* `win01`: Windows Server 2019 Base (no containers!), t3.2xlarge (8 cores, 32 GB), 80G gp3 storage

After creating the virtual machines, note down
* the public IP address of `ubuntu01`
* the internal IP addresses of both `ubuntu01` and `win01`.

## Preparing ubuntu01

### Copying files

Copy the entire k8sfortifylab project into a folder on ubuntu01; either by simply copying using your ssh client, or by cloning it directly from Gitlab. (In the latter case, you may want to [create and register a fresh SSH key](https://docs.gitlab.com/ee/ssh/).) We'll assume this directory to be `~/k8sfortifylab`, although that's not a requirement.

Copy the "Items to be uploaded to the demo environment" mentioned above into `~/k8sfortifylab/prereq`. This will take a while, but there's no need to wait for it before proceeding with some of the steps below.

Find out the DNS server you're using, by issuing `systemd-resolve --status`, and note this down.

### Editing the environment variables

Copy `~/k8sfortifylab/prereq/setenv_example.sh` into `~/k8sfortifylab/prereq/setenv.sh`, and enter appropriate values everywhere. 
* Network routes need to include the subnets of your virtual machine network / VPC; may be left empty in case your workstation and virtual machines are in the same network and you can access the virtual machines directly.
* Select a password. The sample suggest choosing a single password and storing it in `PWD_DEMO`, which is then used for everything else. Alternatively, you may choose varying passwords.
* Set the internal IP addresses of `ubuntu01`, `win01` and your DNS server (`DNS_FORWARD`).
* Optionally, add more DNS entries in `DNS_OPTIONAL`, or leave this out for now.
* Set the correct `DOCKER_USERNAME` and `DOCKER_PASSWORD` to download Fortify private images.
* Parameters `DAST_EDASTDB`, `DAST_TOKEN` and `NEXUSIQSYNC_SSC_TOKEN` cannot be set at this point, we'll set them later. You can already set `NEXUSIQSYNC_IQSERVER_USER` and `NEXUSIQSYNC_IQSERVER_PWD` but be aware that these don't set the NexusIQ server credentials; rather you inform the sychronization tool of them. You must make sure you manually set the NexusIQ server credentials accordingly.

### Configuring DNS

````bash
cd ~/k8sfortifylab/infra/dns/server
./install-dns.sh

cd ~/k8sfortifylab/infra/dns/client
./set-hostname.sh ubuntu01
./configure-dns.sh
````

### Configuring VPN

````bash
cd ~/k8sfortifylab/infra/openvpn/
./recreate-crypto.sh

cd ~/k8sfortifylab/infra/openvpn/server
./install-vpn.sh
````

Now, copy the contents of `~/k8sfortifylab/infra/openvpn/server/client_pc` to your workstation. Import this in OpenVPN Connect. Before starting the connection, override server IP with the public IP address of `ubuntu01` (which you may need to change upon stops/starts of your VM in case of cloud providers). Connect. 

If all goes well, you now have VPN to the server networking, including DNS resolution. To test:
* start a new SSH session to `ubuntu01.fortifydemo.com`
* start a new Remote Desktop session to `win01.fortifydemo.com` (at this point, there's no real need to login yet; simply being asked for credentials proves that the DNS resolution and VPN routing works)

### Kubernetes master

````bash
cd ~/k8sfortifylab/infra/k8s/master
./install-k8s.sh
./config-k8s.sh
````
Monitor by issuing `kubectl get pods --all-namespaces` every now and then, everything should become ready within a minute or so.

### SSL Certificates

````bash
cd ~/k8sfortifylab/infra/ssl
./recreate-crypto.sh
````
Copy `~/k8sfortifylab/infra/ssl/fortifydemo_ca.crt` to your workstation and import as a trusted root certificate. You might want to copy `fortifydemo_wildcard.pfx` as well since we'll need it later on our workstation; but don't import it.

### MS SQL Server

````bash
cd ~/k8sfortifylab/infra/mssql  
./install-mssql.sh
````

If you like, you can verify the successful installation of SQL Server by connecting to `sql.fortifydemo.com` from your local workstation using Microsoft SQL Server Management Studio, but that's not a requirement.

## Preparing win01

### Basics
If you created a machine in AWS, you need to decrypt the Windows password, which will be long and impossible to remember. Log in using RDP. Search for "change password" to change the password into something reasonable, optionally edit "local security policy" to avoid password expiration.

In "server manager", disable the firewall and real-time protection.
> Obviously, that's just to prevent wasting any time on these topics in our demo. It is _not_ a production recommendation, of course.

Via "control panel", set hostname to `win01` and primary domain name to `fortifydemo.com`. It will ask for a reboot to activate this, but we can do a few other things first and reboot later.

Via "network adapters", modify the network connection's TCP/IP setting. Configure the DNS server to be the internal IP address of `ubuntu01`.

Open a PowerShell Window, and add openssh by issuing `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0`. (This will take a few minutes.) After that, open "services", start OpenSSH to see if it works, and set startup type to "automatic".

Now reboot. You should now be able to connect using your SSH client to `win01.fortifydemo.com`. From there, you can start a CMD shell, an SFTP copy window or a Remote Desktop tunneled over SSH.

### Kubernetes
Copy the contents of `~/k8sfortifylab/infra/k8s/winnode` to `win01`.

Open a PowerShell in this directory and issue `.\install-docker.ps1`. This will trigger a reboot.

After rebooting and reconnecting, again open a PowerShell in this directory and issue `.\install-k8s.ps1`.

Obtain the join command on `ubuntu01`(!) by issuing `kubeadm token create --print-join-command`. Copy this command and execute it on `win01`.

On `win01`, in the PowerShell window, issue `.\download-images.ps1`. That is not strictly necessary but will start some slow downloads of ScanCentral DAST components. Starting that ahead of time will allow us to progress faster.

On `ubuntu01` we can verify that our Windows node is coming up correctly: 
````bash
kubectl get nodes -o wide
kubectl get pods --all-namespaces
````
Everything should become "ready" in a few minutes.

## Deploying Fortify components

### SSC

````bash
cd ~/k8sfortifylab/ssc
./install-ssc.sh
```` 

Monitoring status:
````bash
kubectl describe pod ssc-webapp-0
kubectl logs -f ssc-webapp-0
```` 
After deployment complete ("`Server startup in [107178] milliseconds`"), use your browser to log in to https://ssc.fortifydemo.com, change password and optionally password policy, update rulepacks.

To restart the SSC, you can use:
````bash
kubectl delete pod ssc-webapp-0
````

### LIM

````bash
cd  ~/k8sfortifylab/lim
./install-lim.sh
```` 
Use your browser to log in to https://lim.fortifydemo.com/limadmin/, activate, upload license. Create a license pool. Name and password of license pool are arbitrary, but remember them for the next step. Add your licenses to that pool.

>If you're in a hurry: if the LIM image is still pulling and you're waiting for that, you might proceed with the next stage already and finalize LIM config later. You can already initialize the DAST database before LIM is running. That way, two long-running tasks (Windows images pulls and ScanCentral DAST database init) will run in parallel. If you find yourself waiting on both, you might start with the ScanCentral SAST part since it's technically independent.

### ScanCentral DAST

On the workstation, install and run the DAST Config tool. Use the following parameters:
* database server `sql.fortifydemo.com`
* new database name `edast` (or something else)
* database user `sa`, password as configured in `prereq/setenv.sh`, use the same for both the admin and regular user
* initialize with standard securebase
* use existing certificate `fortifydemo_wildcard.pfx` (copy this from `ubuntu01`, `~/k8sfortifylab/infra/ssl`), password as configured in `prereq/setenv.sh`
* SSC URL: https://ssc.fortifydemo.com, admin, password as set in the SSC web interface
* EDAST API URL: https://edast.fortifydemo.com/api/
* allow all origin for CORS policy
* LIM URL: https://lim.fortifydemo.com/limservice/, username/password as set in `prereq/setenv.sh`, poolname/password as configured in the LIM web interface
* sensortoken: anything, we'll soon copy a string derived from this to the sensors.

After completing the wizard, store the artifact zip, and unpack it.

Now, on `ubuntu01`, modify `~/k8sfortifylab/prereq/setenv.sh`. Set `DAST_EDASTDB` and `DAST_TOKEN` to the values used in your scripts.

````bash
cd ~/k8sfortifylab/dastcontroller
./install-dastcontroller.sh
```` 

In SSC, enable ScanCentral DAST with API URL https://edast.fortifydemo.com/api/. Under security, set content-security-policy to disabled. After reloading SSC in your browser, you should now be able to access the ScanCentral DAST screens. Of course, there isn't any sensor yet. To install one:

````bash
cd ~/k8sfortifylab/dastsensor
./install-dastsensor.sh
```` 
You might follow the log using `kubectl logs -f dastsensor-0`. The sensor should come up and become visible in SSC in a few minutes. This is also a useful practice after you requested a scan; you'll see the request come in, the process of obtaining a license from LIM, etc.

At this point: ScanCentral DAST is fully operational. My favourite simple test: create an SSC application Zero Bank 1.0, and run an unauthenticated test of http://zero.webappsecurity.com with the Criticals+Highs policy. This should complete in a few minutes.

### ScanCentral SAST

````bash
cd ~/k8sfortifylab/sastcontroller
./install-sastcontroller.sh
````
Test by opening https://scsast.fortifydemo.com/scancentral-ctrl in your browser.

In SSC, enable scancentral SAST with URL https://scsast.fortifydemo.com/scancentral-ctrl. For a demo, I like to set the poll period short, to 10 seconds. The SAST shared secret must match what you selected in `prereq/setenv.sh`.

Restart SSC `kubectl delete pod ssc-webapp-0`. After restart, the ScanCentral SAST Controller should be visible in SSC.

To add a sensor:

````bash
cd ~/k8sfortifylab/sastsensor
./install-sastsensor
````

### Nexus IQ

````bash
cd ~/k8sfortifylab/nexusiq
./install-nexusiq.sh
````
Log in to https://nexusiq.fortifydemo.com. Default login is `admin`/`admin123`. Change the password (this must match `NEXUSIQSYNC_IQSERVER_USER` and `NEXUSIQSYNC_IQSERVER_PWD` in `prereq/setenv.sh`). Enable  "automatic applications" for the sandbox organization, for convenience.

In SSC, install parser plugin `sonatype-plugin-20.1.20200914.jar`. Also, create a CI Token for `nexusiqsync` (you need the encoded version), and put this in `prereq/setenv.sh` under `NEXUSIQSYNC_SSC_TOKEN`.

To deploy the Sonatype integration service:
````bash
cd ~/k8sfortifylab/nexusiqsync
./install-nexusiqsync.sh
sudo cp mapping_example.json /pv/nexusiqsync/mapping.json
````
And of course, edit `/pv/nexusiqsync/mapping.json` to match your sample project(s). You can do that dynamically without have to restart/redeploy the integration service. It is configured to sync every 30 seconds.

### Jenkins

````bash
cd ~/k8sfortifylab/jenkins
./install-jenkins.sh
kubectl logs -f jenkins-0
````
By following the logs, you'll get the initial Jenkins password. Log in to https://jenkins.fortifydemo.com. Install the recommended plugins, create the admin user. After that, install the `Fortify` and `Nexus Platform` plugins. Under server configuration, configure the connections to both Fortify SSC and Nexus IQ server. For Fortify SSC, you'll need two tokens, each in decoded form: a `CIToken` and a `ScanCentralCtrlToken`.

To ensure the Fortify Maven plugin is installed as well, log in to the Jenkins container:
````bash
kubectl exec -it jenkins-0 -- /bin/bash
````
and install the Maven plugin:
````bash
cd /tmp/fortifymvn
mvn install
````

That's it. Now you can create a job in Jenkins (I tend to use [Insecure Forum](https://github.com/fransvanbuul/insecureforum) as a simple sample application), and do both Fortify scans (post-build step) and Nexus policy evaluations (build step). If you configure `/pv/nexusiqsync/mapping.json` correctly, both will end up in SSC.

### Adding more nodes

Adding nodes is cool because it will allow you to very easily scale out SAST and DAST, e.g:

````bash
kubectl scale --replicas=3 sts/sastsensor
kubectl scale --replicas=3 sts/dastsensor
````

When adding a node of any type, make sure to edit `~/k8sfortifylab/prereq/setenv.sh` and add lines to `DNS_OPTIONS` of the form `<hostname> IN A <ip address>`. After that, on `ubuntu01`:
````bash
cd ~/k8sfortifylab/infra/dns/server
./update-dns.sh
````

To add a Linux node, you'll need to do the `set-hostname.sh`, `configure-dns.sh` and `install-k8s.sh` steps of the master installation, but do NOT issue `configure-k8s.sh`, because that would make it an independent master. Instead, do like you did for `win01`: obtain a cluster join command and execute it.

The add another Windows node, follow exactly the same process as for the first Windows node, just give it a different hostname.

### Some useful debugging stuff

If the VPN won't work as planned, you might want to inspect the iptables and/or monitor packets:
````bash
sudo iptables -S FORWARD
sudo iptables -S POSTROUTING -t nat
sudo tcpdump -nnvi any icmp
````

Kubernetes commands I regularly use:
````bash
kubectl delete pod [podname]
kubectl describe pod [podname]
kubectl logs [-f] [podname]
kubectl get nodes 
kubectl get pods
kubectl exec -it pod -- [/bin/bash|cmd.exe|powershell.exe]
kubectl apply -f [config.yaml]
kubectl delete -f [config.yaml]
````
Many command accept namespaces. The Fortify pods are in the default namespace. Explictly choose all or a particular namespace using `--all-namespaces` or `-n [namespace]`. Also, many commands accept `-o wide` as a flag to provide more detailed output.

After restarting the LIM container (including after a full system restart), LIM will be in a bad state and scans won't start. If you do a "force license refresh" in LIM, you'll get the message "Provided public key value is different from expected one." This can be fixed by doing an "update" under server configuration first, then again try the license refresh.

If you have ScanCentral DAST scans in a bad/polluted state, bring down the DAST sensors and controllers, then clean up the relevant tables in the database with the following script. (This will delete all scans and all sensors, but it will not remove results that are already in SSC as FPRs.)
````bash
cd ~/k8sfortifylab/dastcontroller
./delete-scans-sensors.sh
````
