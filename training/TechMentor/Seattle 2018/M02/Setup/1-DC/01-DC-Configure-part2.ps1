# Create KDS Root Key
Add-KdsRootKey -EffectiveTime (Get-Date).AddHours(-10)

# Download the certificate for later use
$CertName="star.myo365.site.pfx"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
wget "https://github.com/Gerenios/public/blob/master/training/TechMentor/Seattle%202018/M02/$CertName\?raw=true" -OutFile "$env:TEMP\$CertName"