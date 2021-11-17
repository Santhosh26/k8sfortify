Set-Service -Name Docker -StartupType 'Automatic'
Start-Service Docker
Write-Host 'Waiting a few seconds for Docker to start-up'
Start-Sleep -s 5
curl.exe -LO https://github.com/kubernetes-sigs/sig-windows-tools/releases/latest/download/PrepareNode.ps1
.\PrepareNode.ps1 -KubernetesVersion v1.18.15
Write-Host "Now execute the join command as obtained from the master"
Write-Host "To get a fresh join command on the master: kubeadm token create --print-join-command"
