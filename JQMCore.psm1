<#

    JQMCore.psm1

    Contains all core functionality for other PowerShell modules

    06/24/2015 JMM Created

#>


$JQM_DOT_NET_FRAMEWORK_PATH = 'C:\Windows\Microsoft.NET\Framework\v4.0.30319'
If ( (Get-WmiObject Win32_OperatingSystem).OSArchitecture -eq '64-bit' ) {
    $JQM_DOT_NET_FRAMEWORK_PATH = $JQM_DOT_NET_FRAMEWORK_PATH.Replace('\Framework\','\Framework64\')
}

##################################################################################

function Get-YYYYMMDD {
    [DateTime]::Today.ToString("yyyyMMdd")      
}

##################################################################################


function Split-IntoHashtable {
    param (	
        [Parameter(Mandatory=$true)]
        [int]$numberOfHashTables,

        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [Array]$InputObject
    )

    begin {
        #Initialize HashTable with empty arrays
        $hashTable = @{}
        for ($i=0; $i -lt $numberOfHashTables; $i++) {
            $hashTable[ $i ] = @()
        }

        #Initialize which key in the hashtable
        $key = 0
    }
    process {
        $hashTable[(($key++) % $numberOfHashTables)] += ,@($_)
    }
    end {
        return $hashTable | Sort-Object
    }

}

##################################################################################

<#
    Revision History

    03.17.2015 JMM Initial version
#>

function New-ZeroLengthFile
{
<#
.SYNOPSIS
Creates a zero-length file.

.DESCRIPTION
New-ZeroLengthFile creates a zero-length file.

.INPUTS
You can pipe the name of the file to New-ZeroLengthFile.

.OUTPUTS
This function does not produce any output.

#>
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        # The name of the file to create
        [string[]] $InputObject
    )

    process {
        [System.IO.File]::Create($_).Dispose()
    }
}


##################################################################################


function Get-AssemblyVersion
{
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $assemblyPath
    )


    $FAILED_STRING = 'Failed'
    $retVal = @()
    $jobRetry = 3

    # Create return object with every assembly name
    ForEach ( $asm in $assemblyPath ) {
        $retVal += New-Object –TypeName PSObject  -Property @{FullName = $($asm | Resolve-Path).ToString(); Version = $FAILED_STRING}
    }

    # Assembly has to be loaded either in a separate AppDomain, or a whole separate process
    # Since Powershell Jobs are run in separate processes, we'll do it in a job
    # Run the job a few times in case there are errors (if two assemblies are the same, etc.

    While ($jobRetry -gt 0) {
        --$jobRetry

        $failed = $retVal | Where-Object { $_.Version -eq $FAILED_STRING } | Select-Object -ExpandProperty FullName
        If ( $failed -ne $null ) {
            $job = Start-Job -ArgumentList $failed {

                Param([string[]] $asmList)

                $retVal = @{}
                ForEach ( $assemblyPath In $asmList ) {
                    $result = $FAILED_STRING
                    try {
                        $asm = [System.Reflection.Assembly]::ReflectionOnlyLoadFrom($assemblyPath)
                        $asmName = $asm.FullName
                        $pVersion = $asmName.IndexOf("Version=")
                        if ( $pVersion -gt 0 ) {
                            $pComma = $asmName.IndexOf(',',$pVersion)
                            if ( $pComma -gt 0 ) {
                                $result = $asmName.Substring($pVersion + 8, $pComma - $pVersion - 8)
                            }
                        }
                    }
                    finally {
                        $retVal.Add($assemblyPath,$result)
                    }
                }
                return $retVal
            }

            ($job | Wait-Job |Receive-Job).GetEnumerator() | ForEach-Object {
                $dictEntry = $_
                $retVal | Where-Object { $_.FullName -eq $dictEntry.Name } | ForEach-Object { $_.Version = $dictEntry.Value }
            }

        }
        else {
            # No more failures, we can exit the loop
            $jobRetry = 0
        }

    }

    return $retVal
}


##################################################################################


function Get-Intersection
{
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [string[]]$inputObject,

        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [object]$CompareWith
    )
    begin {
        $compareList = @($CompareWith)
        $returnValue = @()
    }
    process {
        if ( $compareList -contains $_ ) { $returnValue += @($_) }
    }
    end {
        return @(,$returnValue)
    }
}


##################################################################################


function Get-Specified
{
    Param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [AllowEmptyCollection()]
        [string[]]$inputObject,

        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$CompareWith
    )

    begin {
        $compareList = @($CompareWith)

        $returnValue = @()
    }
    process {
        if ( ($compareWith -eq $null) -or ($compareList -contains $_) ) { $returnValue += @($_) }
    }
    end {
        return @(,$returnValue)
    }
    
}


##################################################################################


filter ConvertTo-RemotePath ([string]$ComputerName, [Switch]$IncludeProvider)
{
    if ( $_.Length -gt 1 ) {
        if ( $_[1] -eq ':' ) {
            if ( $IncludeProvider ) {
				# For details on this, see http://stackoverflow.com/questions/14653851/need-help-on-powershell-copy-item-from-network-drives
                $provider = 'Microsoft.PowerShell.Core\FileSystem::'
            }
            Else {
                $provider = [String]::Empty
            }
            $_.Replace("$($_[0]):","$provider\\$ComputerName\$($_[0])`$")
        }
        else { $_ }
    }
    else { $_ }
}

##################################################################################


filter Select-QuotedIfNeeded {

    if ( $_.StartsWith('"') -and $_.EndsWith('"') ) { $_ }
    else {
		if ( $_.Contains('"') ) { $_ }
		else {
			if ( $_.Contains(' ') ) { "`"$_`"" }
			else { $_ }
		}
	}
}


##################################################################################


function Get-DotNetVersion {
    Param(
        [Parameter(Mandatory=$false)]
        [string[]]$ComputerName
    )


    # reference here:
    # http://msdn.microsoft.com/en-us/library/hh925568(v=vs.110).aspx

    $scriptBlock = {
        $key = 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP'

        If ( Test-Path "$key\v4" ) {
            If ( Test-Path "$key\v4\Full" ) {
                $releaseValueHolder = Get-ItemProperty "$key\v4\Full" -Name 'Release' -ErrorAction SilentlyContinue
                If ( $releaseValueHolder -ne $null ) {
                    switch ($releaseValueHolder.Release) {
                        381029 {"4.6"}
                        379893 {"4.5.2"}
                        378758 {"4.5.1"}
                        378675 {"4.5.1"}
                        378389 {"4.5"}
                        default {"unknown"}
                    }
                }
                Else {"4.0"}
            }
            Else {"4.0"}
        }
        Else {
            If ( Test-Path "$key\v3.5" ) {"3.5"}
            Else {
                If ( Test-Path "$key\v3.0" ) {"3.0"}
                Else {"2.0"}
            }
        }
    }

    If ( $ComputerName -eq $null ) {
        . $scriptBlock
    }
    Else {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock | %{ $_ | Select-Object @{Name='ComputerName';Expression={$_.PSComputerName}}, @{Name='Version';Expression={$_.ToString()}} }
    }


}

##################################################################################


function Invoke-Executable {

    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $FilePath,

        [string[]]$Parameters,

        [parameter(Mandatory=$false)]
        [Switch]$WhatIf
    )

    If (!(Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    If ( $Parameters -eq $null ) {
        $Parameters = @()
    }

    $parametersOneLine = [string]::Join(' ',$Parameters)

    If ( $WhatIf ) {
        Write-Output "The following would be called:"
        Write-Output "$FilePath $parametersOneLine"
    }
    else {
        Write-Verbose "Calling $FilePath $parametersOneLine" 
        & $FilePath $Parameters
        Write-Verbose "$($FilePath | Split-Path -Leaf) returned with exit code $LASTEXITCODE"
    }
    
}



##################################################################################

function Invoke-Robocopy {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string] $Destination,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Files,

        [Parameter(Mandatory=$false)]
        [int] $NumberOfRetries = 0,

        [parameter(Mandatory=$false)]
        [Switch] $Recurse,

        [parameter(Mandatory=$false)]
        [Switch] $Mirror,

        [parameter(Mandatory=$false)]
        [Switch]$WhatIf
    )


    $Parameters = @( ($Path | Select-QuotedIfNeeded), ($Destination | Select-QuotedIfNeeded) )

    If ( $Files -ne $null ) {
        $Files | ForEach-Object {
            $OneFile = $_
            If ( ![string]::IsNullOrEmpty($OneFile) ) {
                $Parameters = $OneFile | Select-QuotedIfNeeded
            }
        }
    }

    If ($Mirror) {
        $Parameters += @("/mir")
    }
    else {
        If ($Recurse) {
            $Parameters += @("/e")
        }
    }

    # Special version of -WhatIf
    If ( $WhatIf ) {
        $Parameters += @('/L')
    }
    Else {
        # Add these always
        $Parameters += @("/r:$NumberOfRetries", '/NFL','/NDL','/NJH')
    }

    $return = Invoke-Executable "$env:SystemRoot\System32\ROBOCOPY.EXE" $Parameters

    If ($LASTEXITCODE -gt 7 ) {
        Write-Error $return
    }
    Else {
        Write-Output "ROBOCOPY $([string]::Join(' ',$Parameters))"
        If ( $WhatIf ) {
           $return
        }
        Else {
            # TODO: Parse output
            $return | Select-String -Pattern '(Copied|Dirs|Files)' | Select-Object -ExpandProperty Line
            Write-Output `n`r
        }
    }

}

##################################################################################

function Update-Tokens {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNull()]
        [HashTable] $hashTable,

        [Parameter(ValueFromPipeline=$true)]
        [string[]] $InputObject
    )
    process {
        $theString = $_.ToString()
        $hashTable.GetEnumerator() | ForEach-Object {
            $theString = $theString -replace $_.Key, $_.Value
        }
        $theString
    }

}

##################################################################################


Function Enable-VcVars {

    Param (
        [string] $Platform = 'x86',

        [string] $VisualStudioVersion
    )

    If ( [String]::IsNullOrEmpty($env:VISUALSTUDIOVERSION) ) {

        $PathToVcVars = @(
            'c:\Program Files (x86)\Microsoft Visual Studio 12.0\VC'
            ,'c:\Program Files\Microsoft Visual Studio 12.0\VC'
            ,'c:\Program Files (x86)\Microsoft Visual Studio 11.0\VC'
            ,'c:\Program Files\Microsoft Visual Studio 11.0\VC'
        ) | Where-Object { Test-Path $_ } | Where-Object { $_ -like "*$VisualStudioVersion*" } | Select-Object -First 1

        If ($PathToVcVars -eq $null) {
            Write-Error "Could not locate Visual Studio Version $VisualStudioVersion"
        }
        Else {
            Push-Location $PathToVcVars
            cmd /c "vcvarsall.bat $Platform&set" | Where-Object { $_ -match '=' } | ForEach-Object {
                $v = $_.Split('=')
                Set-Item -Path "ENV:\$($v[0])" -Value $v[1] -Force
            }
            Pop-Location
        }
        If ( !([String]::IsNullOrEmpty($env:VISUALSTUDIOVERSION)) ) {
            return "Variables for Visual Studio $env:VISUALSTUDIOVERSION have been set."
        }

    }
    Else {
        return "Variables for Visual Studio $env:VISUALSTUDIOVERSION are already set."
    }
}














