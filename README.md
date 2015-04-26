# PoshAppVeyor
PowerShell Module to help build and test powershell modules using appveyor

[![Build status](https://ci.appveyor.com/api/projects/status/eq6llmtyoyfbjc66/branch/master?svg=true)](https://ci.appveyor.com/project/TravisEz13/poshappveyor/branch/master)

WMF/PowerShell 5 Installation
--------------------------------
From PowerShell run:

	Register-PSRepository -Name converttohtml -SourceLocation https://ci.appveyor.com/nuget/poshappveyor-odx6b5glnf32
	Install-Module converttohtml -Scope CurrentUser

WMF/PowerShell 4 Installation
-----------------------------
 1. Download nuget.exe from [NuGet.org](https://nuget.org/nuget.exe) 
 2. &nuget.exe install ConvertToHtml -source https://ci.appveyor.com/nuget/poshappveyor-odx6b5glnf32 -outputDirectory "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\" -ExcludeVersion

Examples/Testing:
-----------------

See the following files:

* Appveyor.yml
*.\tools\AppveyorPhases.psm1