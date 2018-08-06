Set-ExecutionPolicy Unrestricted -Scope Process -Force

$MyDomain="demolab.myo365.site"
$AdminName="adfsadmin"
$AdminPwd="Qwerty1234567"
$Credential = New-Object -TypeName PSCredential -ArgumentList $AdminName, (ConvertTo-SecureString $AdminPwd -AsPlainText -Force)

# Set DC as dns server
Set-DnsClientServerAddress -InterfaceIndex (Get-Netadapter).InterfaceIndex -ServerAddresses ("10.0.0.4","8.8.8.8")

# Add client to domain
Add-Computer -DomainName $MyDomain -Restart -Credential $Credential