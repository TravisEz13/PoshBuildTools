[string] $moduleDir = Split-Path -Path $script:MyInvocation.MyCommand.Path -Parent

Set-StrictMode -Version latest
Write-Verbose 'Initializing PoshBuildTools'
$webClient = New-Object 'System.Net.WebClient';
$global:appveyor_repoName = ${env:APPVEYOR_REPO_NAME}
$global:appveyor_repoBranch = $env:APPVEYOR_REPO_BRANCH
$global:appveyor_pullRequestTitle = ${env:APPVEYOR_PULL_REQUEST_TITLE}
$script:BuildVersion = '1.0.0.0'
if($env:APPVEYOR_BUILD_VERSION)
{
    $script:BuildVersion = $env:APPVEYOR_BUILD_VERSION
}
$script:moduleBuildCount = 0
$script:failedTestsCount = 0
$script:passedTestsCount = 0
function Invoke-RunTest {
    [CmdletBinding()]
    param
    (
        [CmdletBinding()]
        [string]
        $Path, 
        
        [Object[]] 
        $CodeCoverage
    )
    Write-Info "Running tests: $Path"
    $testResultsFile = 'TestsResults.xml'
    
    $res = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru @PSBoundParameters
    New-AppVeyorTestResult -testResultsFile $testResultsFile
    Write-Info 'Done running tests.'
    return $res
}

Function Invoke-AppveyorInstall
{
    [CmdletBinding()]
    param
    (
        [switch]
        $skipPesterInstall,
        [switch]
        $skipConvertToHtmlInstall
    )

    Write-Info 'Starting Install stage...'
    Write-Info "Repo: $global:appveyor_repoName"
    Write-Info "Branch: $global:appveyor_repoBranch"
    if($global:appveyor_pullRequestTitle)
    {
        Write-Info "Pull Request:  $global:appveyor_pullRequestTitle"    
    }

    if(!$skipPesterInstall)
    {
        Install-NugetPackage -package pester
    }
    
    if(!$skipConvertToHtmlInstall)
    {
        Install-NugetPackage -package ConvertToHtml -source https://ci.appveyor.com/nuget/converttohtml
    }

    Write-Info 'End Install stage.'
}

function Test-BuildInfoList
{
    [CmdletBinding()]
    param
    (
        $list
    )
    
    $list | ForEach-Object {
        if($_.pstypenames -inotcontains $buildInfoType)
        {
            throw "Must be an array of type $buildInfoType"
        }
    }
    return $true
}
Function Invoke-AppveyorBuild
{
    [CmdletBinding()]
    param
    (
        [ValidateScript({ Test-BuildInfoList -list $_})]
        [PsObject[]] $moduleInfoList,
        [switch] $publishModule
    )
    Write-Info 'Starting Build stage...'
    mkdir -force .\out > $null
    mkdir -force .\nuget > $null
    mkdir -force .\examples > $null

    foreach($moduleInfo in $moduleInfoList)
    {
        $ModuleName = $moduleInfo.ModuleName
        $ModulePath = $moduleInfo.ModulePath
        if(test-path $modulePath)
        {
            Update-ModuleVersion -modulePath $ModulePath -moduleName $moduleName
            
            if($publishModule)
            {
                Update-Nuspec -modulePath $ModulePath -moduleName $ModuleName

                Write-Info 'Creating nuget package ...'
                nuget pack "$modulePath\${ModuleName}.nuspec" -outputdirectory  .\nuget
            }

            Write-Info 'Creating module zip ...'
            7z a -tzip ".\out\$ModuleName.zip" ".\$ModuleName\*.*"

            $script:moduleBuildCount ++
        }
        else 
        {
            Write-Warning "Couldn't find module, $ModuleName at $ModulePath.."
        }
    }
    Set-AppveyorBuildVariable -Name PoshBuildTool_ModuleCount -Value $script:moduleBuildCount
    Write-Info 'End Build Stage.'
}
Function Invoke-AppveyorFinish
{
    [CmdletBinding()]
    param
    (
        [ValidateScript({ Test-BuildInfoList -list $_})]
        [PsObject[]] $moduleInfoList,
        [int] $expectedModuleCount
    )
    Write-Info 'Starting finish stage...'


    if ($env:PoshBuildTool_failedTestsCount -gt 0) 
    { 
        throw "${env:PoshBuildTool_failedTestsCount} tests failed."
    } 
    elseif($env:PoshBuildTool_passedTestsCount -eq 0)
    {
        throw 'no tests passed'
    }
    elseif($env:PoshBuildTool_ModuleCount -ne $expectedModuleCount)
    {
        throw "built ${env:PoshBuildTool_ModuleCount} modules, but expected ${expectedModuleCount}"
    } 
    else 
    {       
        if($global:appveyor_repoBranch -ieq 'master' -and [string]::IsNullOrEmpty($global:appveyor_pullRequestTitle))
        {
        Get-ChildItem .\nuget | % { 
                    Write-Info "Pushing nuget package $_.Name to Appveyor"
                    Push-AppveyorArtifact $_.FullName
            }
        }
        else 
        {
            Write-Info 'Skipping nuget package publishing because the build is not for the master branch or is a pull request.'
        }
    }
    Get-ChildItem .\out | % { Push-AppveyorArtifact $_.FullName }
    Write-Info 'End Finish Stage.'

}
Function Invoke-AppveyorTest
{
    [CmdletBinding()]
    param
    (
        [ValidateScript({ Test-BuildInfoList -list $_})]
        [PsObject[]] $moduleInfoList
    )
    Write-Info 'Starting Test stage...'
    # setup variables for the whole build process
    #
    #

    foreach($moduleInfo in $moduleInfoList)
    {
        $ModuleName = $moduleInfo.ModuleName
        $ModulePath = $moduleInfo.ModulePath
        $ModulePath = $moduleInfo.ModulePath
        if(test-path $modulePath)
        {
            $CodeCoverage = $moduleInfo.CodeCoverage
            $tests = $moduleInfo.Tests
            $tests | %{ 
                $res = Invoke-RunTest -Path $_ -CodeCoverage $CodeCoverage
                $script:failedTestsCount += $res.FailedCount 
                $script:passedTestsCount += $res.PassedCount 
                $CodeCoverageTitle = 'Code Coverage {0:F1}%'  -f (100 * ($res.CodeCoverage.NumberOfCommandsExecuted /$res.CodeCoverage.NumberOfCommandsAnalyzed))
                $res.CodeCoverage.MissedCommands | ConvertTo-FormattedHtml -title $CodeCoverageTitle | out-file .\out\CodeCoverage.html
            }
        }
    }
    Set-AppveyorBuildVariable -Name PoshBuildTool_FailedTestsCount -Value $script:failedTestsCount
    Set-AppveyorBuildVariable -Name PoshBuildTool_PassedTestsCount -Value $script:PassedTestsCount

    Write-Info "End Test Stage, Passed: $script:passedTestsCount ; failed $script:failedTestsCount"
}


function New-AppVeyorTestResult
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0, HelpMessage='Please add a help message here')]
        [Object]
        $testResultsFile
    )    

    Invoke-WebClientUpload -url "https://ci.appveyor.com/api/testresults/nunit/${env:APPVEYOR_JOB_ID}" -path $testResultsFile 
}
function Invoke-WebClientUpload
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [Object]
        $url,
        
        [Parameter(Mandatory=$true, Position=1)]
        [Object]
        $path
    )
    
    $webClient.UploadFile($url, (Resolve-Path $path))
}



function Write-Info {
    [CmdletBinding()]
     param
     (
         [Parameter(Mandatory=$true, Position=0)]
         [string]
         $message
     )

    Write-Host -ForegroundColor Yellow  "[APPVEYOR] [$([datetime]::UtcNow)] $message"
}

function Update-ModuleVersion
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $modulePath,

        [Parameter(Mandatory=$true, Position=1)]
        [string]
        $moduleName,

        [ValidateNotNullOrEmpty()]
        [string]
        $version = $script:BuildVersion
        )
    Write-Info "Updating Module version to: $version"

    $moduleInfo = Get-ModuleByPath -modulePath $modulePath -moduleName $moduleName
    if($moduleInfo)
    {
        $newVersion = ConvertTo-Version -version $version
        $FunctionsToExport = @()
        foreach($key in $moduleInfo.ExportedFunctions.Keys)
        {
            $FunctionsToExport += $key
        }
        $psd1Path = (Join-path $modulePath "${moduleName}.psd1")
        $tempFolder = Join-path $env:temp "${ModuleName}-Update-ModuleVersion"
        if(!(test-path $tempFolder))
        {
            mkdir $tempFolder > $null
        }
        $psd1PathUni = (Join-path $tempFolder "${moduleName}.psd1")
        copy-item $psd1Path ".\${moduleName}Original.psd1.tmp"
        New-ModuleManifest -Path $psd1PathUni -Guid $moduleInfo.Guid -Author $moduleInfo.Author -CompanyName $moduleInfo.CompanyName `
            -Copyright $moduleInfo.Copyright -RootModule $moduleInfo.RootModule -ModuleVersion $newVersion -Description $moduleInfo.Description -FunctionsToExport $FunctionsToExport
        Get-Content $psd1PathUni -Raw | out-file -encoding utf8 -filePath $psd1Path -force -width ([int]::MaxValue) 
        remove-item $psd1PathUni
    }
    else {
        throw "Couldn't load moduleInfo for $moduleName"
    }
}

function Get-ModuleByPath
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false, Position=0)]
        [string]
        $modulePath ,

        [Parameter(Mandatory=$false, Position=1)]
        [string]
        $moduleName
    )
    $modulePath = (Resolve-Path $modulePath).ProviderPath
    
    
    Write-Info "Getting module info for: $modulePath"
    
    $getParams = @{}
    if ($PSVersionTable.PSVersion.Major -ge 5)
    {
        $getParams.Add('listAvailable', $true)
        $getParams.add('name',$modulePath)
    }
    else
    {
        Import-Module $modulePath -Force
        $getParams.add('name',$ModuleName)
    }
    
    $moduleInfo = Get-Module @getParams
    return $moduleInfo
}



function ConvertTo-Version
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [String]
        $version
    )
    
    
    $newVersion = New-Object -TypeName 'System.Version' -ArgumentList @($version)
    return $newVersion
}

function Update-Nuspec
{
    [CmdletBinding()]
    param(
        $modulePath,
        $moduleName,
        $version = ${env:APPVEYOR_BUILD_VERSION}
        )

    Write-Info "Updating nuspec: $version; $moduleName"
    $nuspecPath = (Join-path $modulePath "${moduleName}.nuspec")
    [xml]$xml = Get-Content -Raw $nuspecPath
    $xml.package.metadata.version = $version
    $xml.package.metadata.id = $ModuleName
    
    Update-NuspecXml -nuspecXml $xml -nuspecPath $nuspecPath
}
$buildInfoType = 'PoshBuildTools.Build.ModuleInfo'

function New-BuildModuleInfo
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $ModuleName ,

        [Parameter(Mandatory=$true)]
        [string]
        $ModulePath ,

        [string[]] $CodeCoverage,

        [string[]] $Tests
    )

    $moduleInfo = New-Object PSObject -Property @{
        ModuleName = $ModuleName
        ModulePath = $ModulePath
        CodeCoverage = $CodeCoverage
        Tests = $Tests
        }
    $moduleInfo.pstypenames.clear()
    $moduleInfo.pstypenames.add($buildInfoType)
    return $moduleInfo
}
function Update-NuspecXml
{

    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true)]
        [xml]
        $nuspecXml,
        [Parameter(Mandatory=$true)]
        [string]
        $nuspecPath
    )
    
    $nuspecXml.OuterXml | out-file -FilePath $nuspecPath
}


function Install-NugetPackage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$false)]
        [System.String]
        $source = 'https://www.powershellgallery.com/api/v2',
        
        [Parameter(Mandatory=$false)]
        [Object]
        $outputDirectory = "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\",

        [Parameter(Mandatory=$true, Position=0)]
        [String]
        $package
    )

    Write-Info "Installing $package using nuget"
    &nuget.exe install $package -source $source -outputDirectory $outputDirectory -ExcludeVersion
}

function Invoke-FullBuild
{
    [CmdletBinding()]
    param($BuildInfoJsonPath)
    $moduleInfoJson = Get-Content -Raw $BuildInfoJsonPath | ConvertFrom-Json
    $moduleInfoList = @()

    $moduleInfoJson.ModuleInfoList | ForEach-Object { 
        $moduleInfoList += New-BuildModuleInfo -ModuleName $_.ModuleName -ModulePath $_.ModulePath -CodeCoverage $_.CodeCoverage -Tests $_.Tests
    }

    Invoke-AppveyorInstall -skipConvertToHtmlInstall -skipPesterInstall

    Invoke-AppveyorBuild -moduleInfoList $moduleInfoList 

    Invoke-AppveyorTest -moduleInfoList $moduleInfoList 

    Invoke-AppveyorFinish -moduleInfoList $moduleInfoList -expectedModuleCount 1
}

function New-BuildInfoJson
{
    [CmdletBinding()]
        param($BuildInfoJsonPath,
            [ValidateScript({ Test-BuildInfoList -list $_})]
            [PSObject[]]$ModuleInfoList)

        $buildInfo = @{
            Settings = @{}
            ModuleInfoList =$ModuleInfoList
        }
        $buildInfo | ConvertTo-Json | out-file -encoding utf8 $BuildInfoJsonPath -force
}