# PoshBuildTools
PowerShell Module to help build and test powershell modules using appveyor

[![Build status](https://ci.appveyor.com/api/projects/status/eq6llmtyoyfbjc66/branch/master?svg=true)](https://ci.appveyor.com/project/TravisEz13/PoshBuildTools/branch/master)

WMF/PowerShell 5 Installation
--------------------------------
From PowerShell run:

	Register-PSRepository -Name PoshBuildTools -SourceLocation https://ci.appveyor.com/nuget/poshbuildtools
	Install-Module PoshBuildTools -Scope CurrentUser

WMF/PowerShell 4 Installation
-----------------------------
 1. Download nuget.exe from [NuGet.org](https://nuget.org/nuget.exe) 
 2. &nuget.exe install PoshBuildTools -source https://ci.appveyor.com/nuget/poshbuildtools -outputDirectory "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\" -ExcludeVersion

Examples/Testing:
-----------------

See the following files:

* Appveyor.yml
*.\tools\AppveyorPhases.psm1