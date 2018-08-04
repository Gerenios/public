$MyDomain="demolab.myo365.site"
$AdminName="DEMOLAB\adfsadmin"
$AdminPwd="Qwerty1234567"
$Credential = New-Object -TypeName PSCredential -ArgumentList $AdminName, (ConvertTo-SecureString $AdminPwd -AsPlainText -Force)
$CertName="star.myo365.site.pfx"

# Download and install certificate
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
wget "https://github.com/Gerenios/public/blob/master/training/TechMentor/Seattle%202018/M02/$CertName\?raw=true" -OutFile "$env:TEMP\$CertName"
$Thubmprint = (Import-PfxCertificate -FilePath "$env:TEMP\$CertName" -CertStoreLocation Cert:\LocalMachine\My).Thumbprint

# Install ADFS role
Install-WindowsFeature ADFS-Federation –IncludeManagementTools

# Install node to ADFS farm
Import-Module ADFS
Add-AdfsFarmNode `
-CertificateThumbprint:$Thubmprint `
-Credential:$Credential `
-GroupServiceAccountIdentifier:"DEMOLAB\sv_adfs`$" `
-PrimaryComputerName:"adfs-1.demolab.myo365.site" 

# Enable SSO for all browsers
Set-AdfsProperties -WIASupportedUseragents @{add="Mozilla/5.0"}

# Restart the AD FS service
Restart-Service ADFSSRV