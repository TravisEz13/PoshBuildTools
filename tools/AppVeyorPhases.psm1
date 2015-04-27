[string] $moduleDir = Split-Path -Path $script:MyInvocation.MyCommand.Path -Parent

Import-Module $moduleDir\..\PoshBuildTools
Set-StrictMode -Version latest
$webClient = New-Object 'System.Net.WebClient';
$script:expectedModuleCount = 1
$moduleInfoList = @()
$moduleInfoList += New-BuildModuleInfo -ModuleName 'PoshBuildTools' -ModulePath '.\PoshBuildTools' -CodeCoverage @('.\PoshBuildTools\BuildTools.psm1') -Tests @('.\tests')

