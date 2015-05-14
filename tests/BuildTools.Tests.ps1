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
        return @{}
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

    if(${env:APPVEYOR_JOB_ID})
    {
        it 'should call invoke-webclientupdload' -test {
            New-AppVeyorTestResult -testResultsFile 'foobar.xml'
            Assert-MockCalled -ModuleName BuildTools -CommandName Invoke-WebClientUpload -ParameterFilter {
                    $url -eq "https://ci.appveyor.com/api/testresults/nunit/${env:APPVEYOR_JOB_ID}" -and `
                    $path -eq  'foobar.xml'
                }
        }
    }
    else 
    {
        it 'should not call invoke-webclientupdload' -test {
            New-AppVeyorTestResult -testResultsFile 'foobar.xml'
            Assert-MockCalled -ModuleName BuildTools -CommandName Invoke-WebClientUpload -Exactly -times 0
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
        Update-Nuspec -modulePath '.\PoshBuildTools' -moduleName $moduleName -Version $version
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
                $getParams = @{}
                if ($PSVersionTable.PSVersion.Major -ge 5)
                {
                    $getParams.Add('listAvailable', $true)
                }
                else
                {
                    Import-Module ConvertToHtml
                }

                Get-Module ConvertToHtml @getParams |  Should Not BeNullorEmpty
        }
    }
}


Describe 'Invoke-AppVeyorInstall' {
    Mock -ModuleName BuildTools -CommandName Install-NugetPackage -MockWith {
    }

    Mock -ModuleName BuildTools -CommandName Install-Pester -MockWith {
    }
    
    It 'should call install-nugetpackage for pester' {
        Invoke-AppveyorInstall -skipConvertToHtmlInstall
        Assert-MockCalled -ModuleName BuildTools -CommandName Install-Pester -Scope It  -Times 1 -Exactly
    }
    It 'should call install-nugetpackage for converttohtml' {
        Invoke-AppveyorInstall -skipPesterInstall
        Assert-MockCalled -ModuleName BuildTools -CommandName Install-NugetPackage -Scope It -ParameterFilter {
                $package | should be 'ConvertToHtml'
            } -Times 1 -Exactly
    }
}

Describe 'Update-ModuleVersion' -Fixture {
    AfterAll {
        Import-module $modulePath -Force
    }
    Mock -ModuleName BuildTools -CommandName New-ModuleManifest -MockWith {
    }
    Mock -ModuleName BuildTools -CommandName Get-Content -MockWith {
    }
    Mock -ModuleName BuildTools -CommandName Out-file -MockWith {
    }
    Mock -ModuleName BuildTools -CommandName Remove-item -MockWith {
    }
    
    It 'should update version' -test {
        $version = '1.0.0.9'
        $versionObj = ConvertTo-Version -version $version
        $moduleName = 'PoshBuildTools'
        $modulePath = (Resolve-Path (Join-path $RepoRoot '.\PoshBuildTools')).ProviderPath
        $psd1Path = (Join-path $modulePath "${moduleName}.psd1")
        $tempFolder = Join-path $env:temp "${ModuleName}-Update-ModuleVersion"
        $psd1UniPath = (Join-path $tempFolder "${moduleName}.psd1")

        Import-Module $modulePath
        $moduleInfo = Get-ModuleByPath -modulePath $modulePath -moduleName $moduleName

        Update-ModuleVersion -modulePath $modulePath -moduleName 'PoshBuildTools' -Version $version

        Assert-MockCalled -ModuleName BuildTools -CommandName New-ModuleManifest -Scope It -ParameterFilter {
                $ModuleVersion | should be $versionObj
                $Path | should be  $psd1UniPath
                $Author | should be $moduleInfo.Author 
                $CompanyName | should be $moduleInfo.CompanyName 
                $Copyright | should be $moduleInfo.Copyright 
                $RootModule | should be $moduleInfo.RootModule 
                $Description | should be $moduleInfo.Description
                if ($PSVersionTable.PSVersion.Major -ge 5)
                {
                    # these tests don't work in appveyor
                    $Guid | should be $moduleInfo.Guid
                }
            } -Exactly -Times 1
        
    }
}

Describe 'New-BuildModuleInfo' -Fixture {
    It 'should return an object with matching properties' {
        $params = @{
                ModuleName = 'foo'
                ModulePath = 'bar'
                CodeCoverage = @('m1','m2')
                Tests =  @('t1','t2')
            }
        $result = New-BuildModuleInfo @params
        $result.ModuleName | should be $params.ModuleName 
        $result.ModulePath | should be $params.ModulePath
        $result.CodeCoverage[0] | should be $params.CodeCoverage[0] 
        $result.CodeCoverage[1] | should be $params.CodeCoverage[1] 
        $result.Tests[0] | should be $params.Tests[0] 
        $result.Tests[1] | should be $params.Tests[1] 
    }
}

Describe 'Invoke-ProcessTestResults' -Fixture {
    # Cannot invoke pester inside pester so using a job
    <#    $job = start-job -scriptblock {
        param($path, $CodeCoverage, $modulePath, $pesterPath)
        Import-Module -force $modulePath
        Import-Module -force $pesterPath
        return Invoke-RunTest -path $path -CodeCoverage $CodeCoverage

    } -argumentList @("$PSScriptRoot\data\SampleCode.Tests.ps1", "$PSScriptRoot\data\SampleCode.psm1", $modulePath, ((get-module pester).path)) -Verbose
    $results = Receive-Job -Wait -Job $job -Verbose#>
    $results = (Get-Content (Join-path $PSScriptRoot  'data\100PercentResult.json') -raw) | ConvertFrom-Json
    It 'should call implementing function and return hashtable' {
        Mock -ModuleName BuildTools -CommandName New-PesterCodeCov -Verifiable -MockWith {}
        Mock -ModuleName BuildTools -CommandName ConvertTo-FormattedHtml -Verifiable -MockWith {}
        Mock -ModuleName BuildTools -CommandName Out-file -MockWith {}
        Mock -ModuleName BuildTools -CommandName Invoke-RestMethod -MockWith {}
        (Invoke-ProcessTestResults -results $results -token 'FakeToken').GetType().FullName| should Be 'System.Collections.Hashtable'
        Assert-VerifiableMocks
        Assert-MockCalled -ModuleName BuildTools -CommandName Out-file -Exactly -times 0
        Assert-MockCalled -ModuleName BuildTools -CommandName Invoke-RestMethod -Exactly -times 0
    }
}