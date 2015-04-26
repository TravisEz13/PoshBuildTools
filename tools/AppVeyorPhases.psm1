[string] $moduleDir = Split-Path -Path $script:MyInvocation.MyCommand.Path -Parent

Set-StrictMode -Version latest
$webClient = New-Object 'System.Net.WebClient';
$repoName = ${env:APPVEYOR_REPO_NAME}
$branchName = $env:APPVEYOR_REPO_BRANCH
$pullRequestTitle = ${env:APPVEYOR_PULL_REQUEST_TITLE}
$moduleInfo = @{
    'PoshAppVeyor' = @{
        ModulePath = '.\PoshBuildTools'
        CodeCoverage = @('.\PoshBuildTools\BuildTools.psm1')
        Tests = @('.\tests')
                        }
}
Function Invoke-AppveyorInstall
{
    Write-Info 'Starting Install stage...'
    Write-Info "Repo: $repoName"
    Write-Info "Branch: $branchName"
    if($pullRequestTitle)
    {
        Write-Info "Pull Request:  $pullRequestTitle"    
    }
    
    Write-Info "Installing converttohtml"
    &nuget.exe install ConvertToHtml -source https://ci.appveyor.com/nuget/converttohtml-t37xti79gww1 -outputDirectory "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\" -ExcludeVersion

    Write-Info 'End Install stage.'

}

Function Invoke-AppveyorBuild
{
    Write-Info 'Starting Build stage...'
    mkdir -force .\out > $null
    mkdir -force .\nuget > $null
    mkdir -force .\examples > $null

    foreach($moduleName in $moduleInfo.keys)
    {
        $ModulePath = $moduleInfo.$moduleName.ModulePath
        if(test-path $modulePath)
        {
            Update-ModuleVersion -modulePath $ModulePath -moduleName $moduleName
            
            Update-Nuspec -modulePath $ModulePath -moduleName $ModuleName

            Write-Info 'Creating nuget package ...'
            nuget pack "$modulePath\${ModuleName}.nuspec" -outputdirectory  .\nuget

            Write-Info 'Creating module zip ...'
            7z a -tzip ".\out\$ModuleName.zip" ".\$ModuleName\*.*"
        }
        else 
        {
            Write-Warning "Couldn't find module, $ModuleName at $ModulePath.."
        }
    }
    Write-Info 'End Build Stage.'
}

Function Invoke-AppveyorTest
{
    Write-Info 'Starting Test stage...'
    # setup variables for the whole build process
    #
    $script:failedTestsCount = 0
    #

    foreach($moduleName in $moduleInfo.keys)
    {
        $ModulePath = $moduleInfo.$moduleName.ModulePath
        if(test-path $modulePath)
        {
            $CodeCoverage = $moduleInfo.$moduleName.CodeCoverage
            $tests = $moduleInfo.$moduleName.Tests
            $tests | %{ 
                $res = Invoke-RunTest -filePath $_ -CodeCoverage $CodeCoverage
                $script:failedTestsCount += $res.FailedCount 
                $CodeCoverageTitle = 'Code Coverage {0:F1}%'  -f (100 * ($res.CodeCoverage.NumberOfCommandsExecuted /$res.CodeCoverage.NumberOfCommandsAnalyzed))
                $res.CodeCoverage.MissedCommands | ConvertTo-FormattedHtml -title $CodeCoverageTitle | out-file .\examples\CodeCoverage.html
            }
        }
    }

    if ($script:failedTestsCount -gt 0) 
    { 
        throw "$($script:failedTestsCount) tests failed."
    } 
    else 
    {       
        if($branchName -ieq 'master' -and [string]::IsNullOrEmpty($pullRequestTitle))
        {
        Get-ChildItem .\nuget | % { 
                    Write-Info "Pushing nuget package $_.Name to Appveyor"
                    Push-AppveyorArtifact $_.FullName
            }
        }
        else 
        {
            Write-Info "Skipping nuget package publishing because the build is not for the master branch or is a pull request."
        }
    }
    Write-Info 'End Test Stage.'
}
