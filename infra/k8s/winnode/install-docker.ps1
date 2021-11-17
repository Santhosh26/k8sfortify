Install-Module -Name DockerMsftProvider -Repository PSGallery -Force
Install-Package -Name docker -ProviderName DockerMsftProvider  -RequiredVersion 18.09.9
Restart-Computer -Force
