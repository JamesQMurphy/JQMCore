# JQMCore
A collection of core helper functions for PowerShell.  Requires PowerShell v3.0.

## Installation
To use these routines, you can do one of the following:

1. Copy the JQMCore folder and its contents into your PowerShell modules folder.  You can see which folders these are by looking at the PSModulePath environment variable, *or*
2. Create a new folder on your system named "JQMModules" or something to that effect, then copy the JQMCore folder into this folder.  Add the path of the "JQMModules" folder to the PSModulePath environment variable.

## Functions

<table>
	<tr><th>Function</th><th>Description</th></tr>
	<tr><td>Get-YYYYMMDD</td><td>Returns today's date in the format YYYYMMDD</td></tr>
	<tr><td>Split-IntoHashtable</td><td>Splits an array into smaller arrays, and returns a hashtable that contains the arrays</td></tr>
	<tr><td>New-ZeroLengthFile</td><td>Creates a zero-length file</td></tr>
	<tr><td>Get-AssemblyVersion</td><td>Gets the .NET Assembly Version</td></tr>
	<tr><td>Get-Intersection</td><td>Gets the intersection of two arrays</td></tr>
	<tr><td>Get-Specified</td><td>Gets items from a list, or the entire list if nothing is specified</td></tr>
	<tr><td>ConvertTo-RemotePath</td><td>Converts a file to a remote UNC path</td></tr>
	<tr><td>Select-QuotedIfNeeded</td><td>Puts quotes around a string if there are spaces, but not if there are already quotes</td></tr>
	<tr><td>Get-DotNetVersion</td><td>Gets the installed version of .NET on the current system or a list of remote systems</td></tr>
	<tr><td>Invoke-Executable</td><td>Wrapper to invoke an executable</td></tr>
	<tr><td>Invoke-Robocopy</td><td>Wrapper for ROBOCOPY.EXE</td></tr>
	<tr><td>Update-Tokens</td><td>Replaces the tokens in a file</td></tr>
	<tr><td>Enable-VcVars</td><td>Enables Visual Studio Tools</td></tr>
</table>
		
