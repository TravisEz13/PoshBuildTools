# ConvertToHtml
PowerShell Module to convert PSObjects to formatted Html (targeted to Outlook)

WMF/PowerShell 5 Installation
--------------------------------
From PowerShell run:

	Register-PSRepository -Name converttohtml -SourceLocation https://ci.appveyor.com/nuget/converttohtml-t37xti79gww1
	Install-Module converttohtml -Scope CurrentUser

WMF/PowerShell 4 Installation
-----------------------------
 1. Download nuget.exe from [NuGet.org](https://nuget.org/nuget.exe) 
 2. &nuget.exe install ConvertToHtml -source https://ci.appveyor.com/nuget/converttohtml-t37xti79gww1 -outputDirectory "$env:USERPROFILE\Documents\WindowsPowerShell\Modules\" -ExcludeVersion

[![Build status](https://ci.appveyor.com/api/projects/status/j1vu2x67hxjmbtes/branch/master?svg=true)](https://ci.appveyor.com/project/TravisEz13/converttohtml/branch/master)

Examples/Testing:
-----------------

If you make changes, please run the pester tests, and run these two tests:

    Get-Process | ConvertTo-FormattedHtml -OutClipboard

paste the results into outlook and verified they are formatted correctly

    dir| Select-Object Mode, lastwritetime, length, Name | ConvertTo-FormattedHtml -OutClipboard

paste the results into outlook and verified they are formatted correctly

Issues
------
For HTML to work in Outlook 2013 and older, only inline styles can be used.