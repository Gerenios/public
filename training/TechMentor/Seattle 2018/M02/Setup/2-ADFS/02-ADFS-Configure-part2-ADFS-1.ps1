$MyDomain="demolab.myo365.site"
$AdminName="DEMOLAB\adfsadmin"
$AdminPwd="Qwerty1234567"
$Credential = New-Object -TypeName PSCredential -ArgumentList $AdminName, (ConvertTo-SecureString $AdminPwd -AsPlainText -Force)
$CertName="star.myo365.site.pfx"

# Download and install certificate
wget "http://dl.o365.center/$CertName" -OutFile "$env:TEMP\$CertName"
$Thubmprint = (Import-PfxCertificate -FilePath "$env:TEMP\$CertName" -CertStoreLocation Cert:\LocalMachine\My).Thumbprint

# Install ADFS role
Install-WindowsFeature ADFS-Federation –IncludeManagementTools

# Install ADFS farm
Import-Module ADFS
Install-AdfsFarm `
-CertificateThumbprint:$Thubmprint `
-Credential:$Credential `
-FederationServiceDisplayName:"My STS" `
-FederationServiceName:"sts-$MyDomain" `
-GroupServiceAccountIdentifier:"DEMOLAB\sv_adfs`$" 