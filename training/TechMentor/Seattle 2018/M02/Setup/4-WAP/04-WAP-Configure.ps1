$MyDomain="demolab.myo365.site"
$AdminName="DEMOLAB\adfsadmin"
$AdminPwd="Qwerty1234567"
$Credential = New-Object -TypeName PSCredential -ArgumentList $AdminName, (ConvertTo-SecureString $AdminPwd -AsPlainText -Force)
$CertName="star.myo365.site.pfx"

# Download and install certificate
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
wget "https://github.com/Gerenios/public/blob/master/training/TechMentor/Seattle%202018/M02/$CertName\?raw=true" -OutFile "$env:TEMP\$CertName"
$Thubmprint = (Import-PfxCertificate -FilePath "$env:TEMP\$CertName" -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
# To trust SSL
Import-PfxCertificate -FilePath "$env:TEMP\$CertName" -CertStoreLocation Cert:\LocalMachine\AuthRoot

# Set entry to the hosts -file
"`r10.0.0.11 sts-$MyDomain" | Out-File C:\Windows\System32\drivers\etc\hosts -Append ascii

# Install WAP
Install-WindowsFeature Web-Application-Proxy -IncludeManagementTools

# Configure WAP
Import-Module WebApplicationProxy
Install-WebApplicationProxy -FederationServiceName "sts-$MyDomain" -FederationServiceTrustCredential $Credential -CertificateThumbprint $Thubmprint

# Create a firewall rule for load balancer probe
New-NetFirewallRule -DisplayName "AD FS Load Balancer Probe - allow inbound 80" -Group "ADFS" -Direction Inbound -LocalPort 80 -Protocol TCP -Action Allow

# Open .hosts file in notepad
& 'notepad' 'c:\windows\system32\drivers\etc\hosts'