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

Describe 'PowerShell DSC resource modules' {
    
    # Force convert to array
    $psm1Files = @(ls $RepoRoot -Recurse -Filter "*.psm1" -File | ? {
        # Ignore Composite configurations
        # They requires additional resources to be installed on the box
        ($_.FullName -like "*\DscResources\*") -and (-not ($_.Name -like "*.schema.psm1"))
    })

    if (-not $psm1Files) {
        Write-Verbose -Verbose "There are no resource files to analyze"
    } else {

        Write-Verbose -Verbose "Analyzing $($psm1Files.Count) files"

        Context 'Correctness' {

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


            It 'all .psm1 files don''t have parse errors' {
                $errors = @()
                $psm1Files | %{ 
                    $localErrors = Get-ParseErrors $_.FullName
                    if ($localErrors) {
                        Write-Warning "There are parsing errors in $($_.FullName)"
                        Write-Warning ($localErrors | fl | Out-String)
                    }
                    $errors += $localErrors
                }
                $errors.Count | Should Be 0
            }
        }
    }
}