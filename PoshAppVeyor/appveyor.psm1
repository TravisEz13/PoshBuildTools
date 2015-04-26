[string] $moduleDir = Split-Path -Path $script:MyInvocation.MyCommand.Path -Parent

Set-StrictMode -Version latest
$webClient = New-Object 'System.Net.WebClient';
$repoName = ${env:APPVEYOR_REPO_NAME}
$branchName = $env:APPVEYOR_REPO_BRANCH
$pullRequestTitle = ${env:APPVEYOR_PULL_REQUEST_TITLE}

function Invoke-RunTest {
    param
    (
        [string]
        $filePath, 
        
        [Object[]] 
        $CodeCoverage
    )
    Write-Info "Running tests: $filePath"
    $testResultsFile = 'TestsResults.xml'
    $res = Invoke-Pester -Path $filePath -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru -CodeCoverage $CodeCoverage
    $webClient.UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
    Write-Info 'Done running tests.'
    return $res
}

function Write-Info {
     param
     (
         [string]
         $message
     )

    Write-Host -ForegroundColor Yellow  "[APPVEYOR] [$([datetime]::UtcNow)] $message"
}

function Update-ModuleVersion
{
    param(
        $modulePath,
        $moduleName
        )
    Write-Info "Updating Module version to: ${env:APPVEYOR_BUILD_VERSION}"
    $versionParts = ($env:APPVEYOR_BUILD_VERSION).split('.')
    Import-Module $modulePath
    $moduleInfo = Get-Module -Name $moduleName
    $newVersion = New-Object -TypeName 'System.Version' -ArgumentList @($versionParts[0],$versionParts[1],$versionParts[2],$versionParts[3])
    $FunctionsToExport = @()
    foreach($key in $moduleInfo.ExportedFunctions.Keys)
    {
        $FunctionsToExport += $key
    }
    copy-item (Join-path $modulePath "${moduleName}.psd1") ".\${moduleName}Original.ps1"
    New-ModuleManifest -Path .\ConvertToHtml\ConvertTohtml.psd1 -Guid $moduleInfo.Guid -Author $moduleInfo.Author -CompanyName $moduleInfo.CompanyName `
        -Copyright $moduleInfo.Copyright -RootModule $moduleInfo.RootModule -ModuleVersion $newVersion -Description $moduleInfo.Description -FunctionsToExport $FunctionsToExport
}

function Update-Nuspec
{
    param(
        $modulePath,
        $moduleName
        )

    Write-Info "Updating nuspec: ${env:APPVEYOR_BUILD_VERSION}; $moduleName"
    $nuspecPath = (Join-path $modulePath "${moduleName}.nuspec")
    [xml]$xml = Get-Content -Raw $nuspecPath
    $xml.package.metadata.version = $env:APPVEYOR_BUILD_VERSION
    $xml.package.metadata.id = $ModuleName
    $xml.OuterXml | out-file -FilePath $nuspecPath
}