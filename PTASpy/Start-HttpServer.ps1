<#
    .SYNOPSIS
    This is a simple and stupid http server using System.Net.HttpListener.

    .DESCRIPTION
    This is a simple and stupid http server using System.Net.HttpListener.
    It responses to all requests with the given file.

    To exit, make request to url:
    http://<host>/exit
    https://<host>/exit

    .PARAMETER FileToServe
    Path to file to send as a response to all requests.

    .PARAMETER ContentType
    Content type to send as response header. Defaults to text/html

    .PARAMETER Thumbprint
    Thumbprint of the SSL certificate to be used for https. If not provided, uses http.

    .PARAMETER Port
    Port to listen to. If not provided, defaults 80 for http and 443 for https.

    .PARAMETER HostName
    Hostname to listen to. Defaults to * which listens all hostnames.

    .Example
    .\Start-HttpServer.ps1 -FileToServe .\index.html

    .Example
    .\Start-HttpServer.ps1 -FileToServe .\config.xml -ContentType text/xml -Thumbprint "7addc9940bea76befc1c5cb0ef1973dd566efb94"

    .NOTES
    Version: 1.1
    Author:  @DrAzureAD (Dr Nestori Syynimaa)
    Date:    Sep 19 2022
#>
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$True)]
    [String]$FileToServe,
    [Parameter(Mandatory=$False)]
    [String]$ContentType="text/html",
    [Parameter(Mandatory=$False)]
    [String]$Thumbprint,
    [Parameter(Mandatory=$False)]
    [int]$Port=0,
    [Parameter(Mandatory=$False)]
    [String]$HostName="*"
)

# Check that the file exists
if(-not (Test-Path $FileToServe))
{
    Write-Error "The file doesn't exist: $FileToServe"
    return
}

# If port is 0, use default ports
if($port -eq 0)
{
    $port = 80
    if($Thumbprint)
    {
        $port = 443
    }
}

# Set the protocol
$protocol = "http"

# We got certificate thumbprint so let's do some binding
if($Thumbprint)
{
    $protocol = "https"

    # Check that the certificate is in LocalMachine\My store
    if(-not (Test-Path "Cert:\LocalMachine\My\$Thumbprint"))
    {
        Write-Error "The certificate not found from Local Computer Personal store"
        return
    }

    # Remove the existing binding
    Write-Verbose "Removing existing SSL bindings"
    Start-Process "netsh.exe" -ArgumentList "http","delete","sslcert","ipport=0.0.0.0:$Port" -Wait

    # Add the new binding
    Write-Verbose "Binding $Thumbprint to 0.0.0.0:$Port"
    Start-Process "netsh.exe" -ArgumentList "http","add","sslcert","ipport=0.0.0.0:$Port","certhash=$Thumbprint","appid={00000000-0000-0000-0000-000000000000}" -Wait
}

[System.Net.HttpListener]$httpServer = [System.Net.HttpListener]::new()
$prefix = "$($protocol)://$($HostName):$($Port)/"
$httpServer.Prefixes.Add($prefix)
$httpServer.Start()


if($httpServer.IsListening)
{
    Write-Host "Listening $prefix"
    Write-Host "To exit, browse to: $($prefix)exit"

    while($httpServer.IsListening)
    {
        # Get the request and response objects
        [System.Net.HttpListenerContext] $ctx = $httpServer.GetContext()
        [System.Net.HttpListenerRequest] $req = $ctx.Request
        [System.Net.HttpListenerResponse]$res = $ctx.Response

        if($req.RawUrl -eq "/exit")
        {
            Write-Host "Exiting.."
            [byte[]]$body = [text.encoding]::UTF8.GetBytes("Bye!")
            $res.ContentType = "text/plain"
            $res.ContentLength64 = $body.Length
            $res.OutputStream.Write($body,0,$body.Length)
            $res.OutputStream.Close()
            $httpServer.Stop();
        }
        else
        {
            # Write the request to console
            Write-Host ("{0} {1} {2}" -f (Get-Date).ToUniversalTime().ToString("o", [cultureinfo]::InvariantCulture),$req.HttpMethod,$req.Url.AbsoluteUri)

            # Create the response
            [byte[]]$body = Get-Content $FileToServe -Encoding Byte
            $res.ContentType = $ContentType
            $res.ContentLength64 = $body.Length
            $res.OutputStream.Write($body,0,$body.Length)
            $res.OutputStream.Close()
        }
    }
}
