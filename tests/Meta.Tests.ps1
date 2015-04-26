<# 
Copyright Microsoft 2015

.summary
    Test that describes code itself.
    Adapted from:  https://github.com/PowerShell/DscResource.Tests/blob/master/Meta.Tests.ps1

#>

[CmdletBinding()]
param()

if (!$PSScriptRoot) # $PSScriptRoot is not defined in 2.0
{
    $PSScriptRoot = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
}
$RepoRoot = "$PSScriptRoot\.."

# import common for $RepoRoot variable

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

Describe 'Text files formatting' {

    
    if($env:APPVEYOR -eq 'True')
    {
        $extensionList =  @('.gitignore', '.gitattributes', '.ps1', '.psm1', '.json', '.xml', '.cmd', '.mof')
    }
    else 
    {
        # We rewrite the psd1 on appveyor, that's fine as long as it's not checked in.
        $extensionList =  @('.gitignore', '.gitattributes', '.ps1', '.psm1', '.psd1', '.json', '.xml', '.cmd', '.mof')        
    }

    $allTextFiles = Get-ChildItem -File -Recurse $RepoRoot | ? { $extensionList -contains $_.Extension } 
    
    Context 'Files encoding' {

        It "Doesn't use Unicode encoding" {
            $allTextFiles | %{
                $path = $_.FullName
                $bytes = [System.IO.File]::ReadAllBytes($path)
                $zeroBytes = @($bytes -eq 0)
                if ($zeroBytes.Length) {
                    Write-Warning "File $($_.FullName) contains 0 bytes. It's probably uses Unicode and need to be converted to UTF-8"
                }
                $zeroBytes.Length | Should Be 0
            }
        }
    }

    Context 'Indentations' {

        It 'We are using spaces for indentaion, not tabs' {
            $totalTabsCount = 0
            $allTextFiles | %{
                $fileName = $_.FullName
                $tabStrings = (Get-Content $_.FullName -Raw) | Select-String "`t" | % {
                    Write-Warning "There are tab in $fileName"
                    $totalTabsCount++
                }
            }
            $totalTabsCount | Should Be 0
        }
    }
}

Describe 'PowerShell DSC modules' {
    
    # Force convert to array
    $psd1Files = @(ls $RepoRoot -Recurse -Filter "*.psd1" -File)

    if (-not $psd1Files) {
        Write-Verbose -Verbose "There are no modules files to analyze"
    } else {

        Write-Verbose -Verbose "Analyzing $($psd1Files.Count) files"

        Context 'PSD1 Root Module Correctness' {

            function Get-ParseErrors
            {
                param(
                    [Parameter(ValueFromPipeline=$True,Mandatory=$True)]
                    [string]$fileName
                )    

                $tokens = $null 
                $errors = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($fileName, [ref] $tokens, [ref] $errors)
                return $errors
            }


            It 'all .psd1 files don''t have parse errors' {
                $errors = @()
                $psd1Files | %{ 
                    if ($PSVersionTable.PSVersion.Major -eq 4)
                    {
                        Import-Module $_.FullName
                        $moduleName = [System.io.path]::GetFileNameWithoutExtension($_.FullName)
                        $moduleInfo = Get-Module $moduleName
                    }
                    else
                    {                
                        $moduleInfo = Get-Module $_.FullName -ListAvailable
                    }
                    $moduleBase = $moduleInfo.moduleBase
                    $rootModule = $moduleInfo.rootModule
                    $rootModulePath = join-path $moduleBase $RootModule
                    if([System.io.path]::GetExtension($RootModule) -ieq '.psm1')
                    {              
                        Write-Verbose "Getting erros for $RootModulePath" -Verbose
                        $localErrors = Get-ParseErrors $rootModulePath
                        if ($localErrors) {
                            Write-Warning "There are parsing errors in $($rootModule)"
                            Write-Warning ($localErrors | fl | Out-String)
                        }
                        $errors += $localErrors
                    }
                }
                $errors.Count | Should Be 0
            }
        }
    }
}
