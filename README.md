# PoshBuildTools

PowerShell Module to help build and test powershell modules using appveyor

[![Join the chat at https://gitter.im/TravisEz13/PoshBuildTools](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/TravisEz13/PoshBuildTools?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Build status](https://ci.appveyor.com/api/projects/status/l10954k5u06bctie/branch/master?svg=true)](https://ci.appveyor.com/project/TravisEz13/poshbuildtools/branch/master)
[![Stories in Ready](https://badge.waffle.io/TravisEz13/ConvertToHtml.png?label=ready&title=Ready)](https://waffle.io/TravisEz13/ConvertToHtml)
[![codecov.io](http://codecov.io/github/TravisEz13/PoshBuildTools/coverage.svg?branch=master)](http://codecov.io/github/TravisEz13/PoshBuildTools?branch=master)

[![codecov.io](http://codecov.io/github/TravisEz13/PoshBuildTools/branch.svg?branch=master)](http://codecov.io/github/TravisEz13/PoshBuildTools?branch=master)

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
* .\tools\AppveyorPhases.psm1
