# DNS
nslookup -q=MX seattle.o365life.com
nslookup -q=TXT seattle.o365life.com

# Federation Trust
Get-FederationInformation -DomainName gerenios.com | Select -ExpandProperty DomainNames

# User Realm REST API
Invoke-RestMethod -Uri https://login.microsoftonline.com/GetUserRealm.srf?login=nn@tomtom.com

# Sharing
Get-SPOTenant | fl *match*
Set-SPOTenant -RequireAcceptingAccountMatchInvitedAccount $true

# External users
# List users:  https://o365life2018.sharepoint.com/_api/web/siteusers
# List groups: https://o365life2018.sharepoint.com/_api/web/SiteGroups

# OneDrive sync
Get-ADDomain | fl *guid*
Get-SPOTenantSyncClientRestriction
Set-SPOTenantSyncClientRestriction -Enable -DomainGuids 4ca7e9fb-ae31-4d0c-92ed-6f623a5b7e84


# Groups

# Connect to Office 365
Connect-AzureAD -Credential $cred

# Get the current settings
$Settings = Get-AzureADDirectorySetting | where DisplayName -eq "Group.Unified"

# Create a new settings from the template if current settings are empty
if(!$Settings){New-AzureADDirectorySetting -DirectorySetting (Get-AzureADDirectorySettingTemplate | where DisplayName -eq "Group.Unified").CreateDirectorySetting()}
$Settings = Get-AzureADDirectorySetting | where DisplayName -eq "Group.Unified"

# Add a UG_ prefix
$Settings["PrefixSuffixNamingRequirement"] = "UG_[GroupName]"

# Save the settings
Set-AzureADDirectorySetting -DirectorySetting $Settings -Id $Settings.Id

# Disable group creation
$Settings["EnableGroupCreation"] = $False

# Set the group allowed to create Office 365 groups
$Settings["GroupCreationAllowedGroupId"] = (Get-AzureADGroup -SearchString "O365GroupCreators").objectid

# Save the settings
Set-AzureADDirectorySetting -DirectorySetting $Settings -Id $Settings.Id