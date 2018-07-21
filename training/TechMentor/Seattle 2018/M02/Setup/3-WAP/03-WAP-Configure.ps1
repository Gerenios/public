$MyDomain="myo365.site"
$AdminName="MYO365SITE\adfsadmin"
$AdminPwd="Qwerty1234567"
$Credential = New-Object -TypeName PSCredential -ArgumentList $AdminName, (ConvertTo-SecureString $AdminPwd -AsPlainText -Force)
$CertName="star.myo365.site.pfx"

# Download and install certificate
wget "http://dl.o365.center/$CertName" -OutFile "$env:TEMP\$CertName"
$Thubmprint = (Import-PfxCertificate -FilePath "$env:TEMP\$CertName" -CertStoreLocation Cert:\LocalMachine\My).Thumbprint
# To trust SSL
Import-PfxCertificate -FilePath "$env:TEMP\$CertName" -CertStoreLocation Cert:\LocalMachine\AuthRoot

# Set entry to the hosts -file
# NLB klusteri puuttuu!
"`r10.0.0.10 sts.$MyDomain" | Out-File C:\Windows\System32\drivers\etc\hosts -Append ascii

# Install WAP
Install-WindowsFeature Web-Application-Proxy -IncludeManagementTools

# Configure WAP
Import-Module WebApplicationProxy
Install-WebApplicationProxy -FederationServiceName "sts.$MyDomain" -FederationServiceTrustCredential $Credential -CertificateThumbprint $Thubmprint