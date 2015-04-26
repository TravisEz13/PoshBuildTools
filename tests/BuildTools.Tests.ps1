<# 

.summary
    Testing BuildTools.psm1

#>

[CmdletBinding()]
param()

if (!$PSScriptRoot) # $PSScriptRoot is not defined in 2.0
{
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}
$RepoRoot = "$PSScriptRoot\.."

$modulePath = "$RepoRoot\PoshBuildTools\BuildTools.psm1"
Write-Verbose -Verbose "Importing $modulePath"
Import-module $modulePath -Force

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

Describe 'Invoke-RunTest' {
    Mock -CommandName Invoke-Pester -ModuleName BuildTools -MockWith {
    }
    Mock -CommandName New-AppVeyorTestResult -ModuleName BuildTools -MockWith {
    }
    
    It 'Should call pester and new test results' {
        Invoke-runtest -path .\tests 
        Assert-MockCalled -ModuleName BuildTools -CommandName Invoke-Pester -ParameterFilter {
                '.\tests' | should be $Script[0]
                $script.count | should be 1
                $OutputFormat | should be 'NUnitXml'
                $OutputFile | should be 'TestsResults.xml'
            }
        Assert-MockCalled -ModuleName BuildTools -CommandName New-AppVeyorTestResult -ParameterFilter {
                $testResultsFile | should be 'TestsResults.xml'
            } 
    }
    It 'Code coverage parameter should be passed' {
        $codeCov = @('.\module.psm')
        Invoke-runtest -path .\tests2 -CodeCoverage $codeCov
        Assert-MockCalled -ModuleName BuildTools -CommandName Invoke-Pester -ParameterFilter {
                '.\tests2' -eq $Script[0] -and `
                $script.count -eq 1 -and `
                $CodeCoverage -eq @('.\module.psm') -and `
                $OutputFormat -eq 'NUnitXml' -and `
                $OutputFile -eq 'TestsResults.xml'
            }
        Assert-MockCalled -ModuleName BuildTools -CommandName New-AppVeyorTestResult -ParameterFilter {
                $testResultsFile | should be 'TestsResults.xml'
            } 
    }
}

Describe 'Write-Info' {
    Mock -ModuleName BuildTools -CommandName Write-Host -MockWith {
    }
    
    it 'should call write info with the message and yellow' {
        Write-Info -message 'foobar'
        Assert-MockCalled -ModuleName BuildTools -CommandName Write-Host -ParameterFilter {
                Write-Verbose -Verbose -Message "object: $object - $($object[0].Contains('foobar'))"
                Write-Verbose -Verbose -Message "foregroundcolor: $foregroundcolor"
                $object -and
                $object[0].Contains('foobar') -and `
                $foregroundcolor -ieq 'yellow'
            }
        
    }
}

Describe 'New-AppVeyorTestResult' {
    Mock -ModuleName BuildTools -CommandName Invoke-WebClientUpload -MockWith {
    }

    it 'should call invoke-webclientupdload' -test {
        New-AppVeyorTestResult -testResultsFile 'foobar.xml'
        Assert-MockCalled -ModuleName BuildTools -CommandName Invoke-WebClientUpload -ParameterFilter {
                $url -eq "https://ci.appveyor.com/api/testresults/nunit/${env:APPVEYOR_JOB_ID}" -and `
                $path -eq  'foobar.xml'
            }
    }

}

Describe 'Update-Nuspec' {
    $global:nuspecXml = $null
    Mock -ModuleName BuildTools -CommandName Update-NuspecXml -MockWith {
        $global:nuspecXml = $nuspecXml
    }
    
    It 'Should' -test {
        $version = '1.0.0.9'
        $moduleName = 'PoshBuildTools'
        Update-Nuspec -modulePath '.\PoshBuildTools' -moduleName 'PoshBuildTools' -Version $version
        $global:nuspecXml | should not be $null
        $global:nuspecXml.package.metadata.version | should be $version
        $global:nuspecXml.package.metadata.id | should be $moduleName
    }
}

if(${env:APPVEYOR_BUILD_VERSION})
{
    Describe 'Install-NugetPackage'  -Fixture {
   
        it 'should install converttohtml'  -test {
                Install-NugetPackage -package ConvertToHtml -source https://ci.appveyor.com/nuget/converttohtml
                Get-Module ConvertToHtml -ListAvailable |  Should Not BeNullorEmpty
        }
    }
}