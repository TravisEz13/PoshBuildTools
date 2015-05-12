<# 

.summary
    Testing SampleCode.psm1

#>

[CmdletBinding()]
param()

if (!$PSScriptRoot) # $PSScriptRoot is not defined in 2.0
{
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}
$RepoRoot = "$PSScriptRoot\.."

$modulePath = "$PSScriptRoot\SampleCode.psm1"
Write-Verbose -Verbose "Importing $modulePath"
Import-module $modulePath -Force

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

Describe 'add' {
    
    It 'Should add 1 + 1 to get 2' {
        add -x 1 -y 1 | should be 2
    }
}

