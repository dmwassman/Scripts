<#
.SYNOPSIS 
    Pull folder permissions from a given path and export to CSV file
.DESCRIPTION 
    Pull ACL permissions from a specified path using PowerShell ACL commandlets and export them to a specified CSV file.
.NOTES 
    Requirements:
        None
    File Name: 
        getFolderPerm.ps1
    By: 
        David Wassman
    Logs:
    
.OUTPUTS 
    CSV file specified
.PARAMETER Path 
    Path to get ACL permissions from
.PARAMETER File 
    Path and file name to export CSV to
#>
[CmdletBinding()]

Param 
(
    [Parameter(mandatory=$true,position=0,ValueFromPipeline=$true)]
    [ValidateScript({Test-Path -Path $_})]
    [string]$Path,
    [Parameter(mandatory=$true,position=1)]
    [ValidateScript({Test-Path -Path $_.Substring(0,$_.LastIndexOf("\"))})]
    [string]$File
)

if(Test-Path -Path $File){
    $null > $File
}

Get-ChildItem -Path $Path -Directory | foreach{
    $folder = $_.FullName
    $(Get-Acl -Path $folder).Access | foreach{
        "$folder,$($_.IdentityReference),$($_.FileSystemRights)" >> $File
    }
    ',' >> $File
}
