## Script by Abdul Farooque
Import-Module adsync
$adConnector = (get-adsyncconnector).name[1]
$aadConnector = (get-adsyncconnector).name[0]
$gs = Get-ADSyncGlobalSettings
$p = New-Object Microsoft.IdentityManagement.PowerShell.ObjectModel.ConfigurationParameter "Microsoft.Synchronize.SynchronizationPolicy", String, SynchronizationGlobal, $null, $null, $null
$p.Value = "Delta"
$gs.Parameters.Remove($p.Name)
$gs.Parameters.Add($p)
Set-ADSyncGlobalSettings -GlobalSettings $gs
$c = Get-ADSyncConnector -Name $adConnector
$p = New-Object Microsoft.IdentityManagement.PowerShell.ObjectModel.ConfigurationParameter “Microsoft.Synchronize.ForceFullPasswordSync”, String, ConnectorGlobal, $null, $null, $null
$p.Value = 1
$c.GlobalParameters.Remove($p.Name)
$c.GlobalParameters.Add($p)
$c = Add-ADSyncConnector -Connector $c
Set-ADSyncAADPasswordSyncConfiguration -SourceConnector $adConnector -TargetConnector $aadConnector -Enable $false
Set-ADSyncAADPasswordSyncConfiguration -SourceConnector $adConnector -TargetConnector $aadConnector -Enable $true 