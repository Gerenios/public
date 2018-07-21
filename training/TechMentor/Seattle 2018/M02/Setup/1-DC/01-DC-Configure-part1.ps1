$MyDomain="demolab.myo365.site"
$DomainNetBiosName="DEMOLAB"
$SafeModePassword="Qwerty1234567"

# Install AD Domain Services
Install-WindowsFeature AD-Domain-Services –IncludeManagementTools

# Promote to domain controller
Import-Module ADDSDeployment
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath “C:\Windows\NTDS” -DomainMode 7 -DomainName $MyDomain -DomainNetbiosName $DomainNetBiosName -ForestMode 7 -InstallDns:$true -LogPath “C:\Windows\NTDS” -NoRebootOnCompletion:$false -SysvolPath “C:\Windows\SYSVOL” -Force:$true -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModePassword -AsPlainText -Force)