<#

    UnitTest.ps1

    Tests the functionality of JQMCore.psm1


#>
cls
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
CD $scriptPath

# Ensure that we don't have the real module loaded
Remove-Module JQMCore -ErrorAction Ignore
$PSModuleAutoloadingPreference = "None"

# Dynamically load the module
$dynamicModules = @()

@('..\JQMCore.psm1') | ForEach-Object {

    $pathToModule = Resolve-Path $_
    $fileContents = Get-Content -Path $pathToModule -Raw

    # Sneaky trick - modules will use $MyInvocation.MyCommand.Definition to get their
    # own path so we have to replace it
    $fileContents = $fileContents.Replace('$MyInvocation.MyCommand.Definition',"`'$pathToModule`'")

    $dynamicModules += @(New-Module -ScriptBlock ([ScriptBlock]::Create($fileContents)) | Import-Module)
}

#####################################################################
#
#              TEST HARNESS
#

$script:failedTests = @()

function Add-FailedTest {
    param (	
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    $script:failedTests += @($Message)
}

function Assert-Count {
    param (	
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TestName,
        
        [Parameter(Mandatory=$true)]
        [System.Collections.ICollection]$testObject,

        [Parameter(Mandatory=$true)]
        [int]$ExpectedCount
    )

    $ActualCount = $testObject.Count
    If ($ExpectedCount -ne $ActualCount) {
        Add-FailedTest "$TestName`: Count is $ActualCount, expected $ExpectedCount"
    }        
}

function Assert-Value {
    param (	
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TestName,
        
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        $TestValue,

        [Parameter(Mandatory=$true)]
        [AllowNull()]
        $ExpectedValue
    )

    If ($TestValue -ne $ExpectedValue) {
        Add-FailedTest "$TestName`: Value is $TestValue, expected $ExpectedValue"
    }        

}




#############################################################
#
#    Get-Intersection
#

$set1 = @('d','e','a','c','b','f')
$set2 = @('x','e','d','q')
$set3 = @('1','2','3')
$setEmpty = @()

$intersection1a = $set1 | Get-Intersection -CompareWith $set2
Assert-Count "Intersection #1a" $intersection1a 2
Assert-Value "Intersection #1a value 1 "$intersection1a[0] 'd'
Assert-Value "Intersection #1a value 2 "$intersection1a[1] 'e'
$intersection1b = $set2 | Get-Intersection -CompareWith $set1
Assert-Count "Intersection #1b" $intersection1b 2
Assert-Value "Intersection #1b value 1 "$intersection1b[0] 'e'
Assert-Value "Intersection #1b value 2 "$intersection1b[1] 'd'

$intersection2a = $set1 | Get-Intersection -CompareWith $setEmpty
Assert-Count "Intersection #2a" $intersection2a 0
$intersection2b = $setEmpty | Get-Intersection -CompareWith $set1
Assert-Count "Intersection #2b" $intersection2b 0

$intersection3a = $set1 | Get-Intersection -CompareWith $set3
Assert-Count "Intersection #3a" $intersection3a 0
$intersection3b = $set3 | Get-Intersection -CompareWith $set1
Assert-Count "Intersection #3b" $intersection3b 0

#############################################################
#
#    Get-Specified
#
$set1 = @('d','e','a','c','b','f')

$specified1 = $set1 | Get-Specified -CompareWith $null
Assert-Count "Specified #1 count" $specified1 6
$specified2 = $set1 | Get-Specified -CompareWith 'b','c','d'
Assert-Count "Specified #2 count" $specified2 3
$specified3 = $set1 | Get-Specified -CompareWith 'x','c','0'
Assert-Count "Specified #3 count" $specified3 1
$specified4 = $set1 | Get-Specified -CompareWith 'x','y','z'
Assert-Count "Specified #4 count" $specified4 0

#############################################################
#
#    Split-IntoHashtable
#

$hashTbl = @( 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180) | Split-IntoHashtable 5

Assert-Count "Split-IntoHashtable #1 number of elements" $hashTbl 5
Assert-Count "Split-IntoHashtable #1 first array number of elements" $hashTbl[0] 4
Assert-Count "Split-IntoHashtable #1 fourth array number of elements" $hashTbl[3] 3
Assert-Value "Split-IntoHashtable: First array element [1] wrong value" ($hashTbl[0])[1] 60
Assert-Value "Split-IntoHashtable: Fourth array element [1] wrong value" ($hashTbl[3])[1] 90


$array03 = @( 'a', 'b', 'c')
$hashTbl = Split-IntoHashtable 8 $array03
Assert-Count "Split-IntoHashtable #2 number of elements" $hashTbl 8

$arrSplit0 = $hashTbl[0]
Assert-Count "Split-IntoHashtable #2 First array wrong number of elements" $arrSplit0 1
Assert-Value "Split-IntoHashtable: First array element [0] wrong value (#2)" $arrSplit0[0] 'a'

$arrSplit7 = $hashTbl[7]
Assert-Count "Split-IntoHashtable #2 Last array not empty" $arrSplit7 0



#############################################################
#
#    Get-YYYYMMDD: Date in YYYYMMDD format
#
$todayInYYYYMMDD = [DateTime]::Today.ToString("yyyyMMdd")
Assert-Value "Get-YYYYMMDD test" $(Get-YYYYMMDD) $todayInYYYYMMDD


#############################################################
#
#    Read file version - TODO
#



#############################################################
#
#    Translate path to remote server
#

Assert-Value "Translate path #1" ('C:\Foo.txt' | ConvertTo-RemotePath 'SERVER') '\\SERVER\C$\Foo.txt'

$locals = @('C:\Path\local1.zzz','C:\X2','F:\Temp\1123192123_123123')
$remotes = $locals | ConvertTo-RemotePath 'Server.domain.corp'
Assert-Count "Tranlsate count" $remotes 3
Assert-Value "Translate path #2.1" $remotes[0] '\\Server.domain.corp\C$\Path\local1.zzz'
Assert-Value "Translate path #2.2" $remotes[1] '\\Server.domain.corp\C$\X2'
Assert-Value "Translate path #2.3" $remotes[2] '\\Server.domain.corp\F$\Temp\1123192123_123123'
Assert-Value "Translate path non-action #1" $('X' | ConvertTo-RemotePath 'XYZ') 'X'
Assert-Value "Translate path non-action #2" $('X123413243214' | ConvertTo-RemotePath 'XYZ') 'X123413243214'

$remotes = $locals | ConvertTo-RemotePath 'Server.domain.corp' -IncludeProvider
Assert-Count "Tranlsate with provider count" $remotes 3
Assert-Value "Translate with provider path #2.1" $remotes[0] 'Microsoft.PowerShell.Core\FileSystem::\\Server.domain.corp\C$\Path\local1.zzz'
Assert-Value "Translate with provider path #2.2" $remotes[1] 'Microsoft.PowerShell.Core\FileSystem::\\Server.domain.corp\C$\X2'
Assert-Value "Translate with provider path #2.3" $remotes[2] 'Microsoft.PowerShell.Core\FileSystem::\\Server.domain.corp\F$\Temp\1123192123_123123'
Assert-Value "Translate path with provider non-action #1" $('X' | ConvertTo-RemotePath 'XYZ' -IncludeProvider) 'X'
Assert-Value "Translate path with provider non-action #2" $('X123413243214' | ConvertTo-RemotePath 'XYZ' -IncludeProvider) 'X123413243214'



#############################################################
#
#    Select-QuotedIfNeeded 
#

Assert-Value "Select-QuotedIfNeeded #1" ('ABC' | Select-QuotedIfNeeded) 'ABC'
Assert-Value "Select-QuotedIfNeeded #1" ('ABC DEF' | Select-QuotedIfNeeded) '"ABC DEF"'
Assert-Value "Select-QuotedIfNeeded #1" ('"ABC DEF"' | Select-QuotedIfNeeded) '"ABC DEF"'
Assert-Value "Select-QuotedIfNeeded #1" ('"ABC"' | Select-QuotedIfNeeded) '"ABC"'


#############################################################
#
#    Invoke-Robocopy - TODO
#


#############################################################
#
#    Update-Tokens
#

$testSourcePath = $scriptPath | Join-Path -ChildPath 'TokenTest.txt'
$testDestPath = $scriptPath | Join-Path -ChildPath 'TokenTest_output.txt'
If ( Test-Path $testSourcePath ) { Remove-Item $testSourcePath -Force }
If ( Test-Path $testDestPath ) { Remove-Item $testDestPath -Force }

@"
This is line 1
TOKEN_1 is on line 2
line 3 has TOKEN_2
TOKEN_1TOKEN_1TOKEN_1TOKEN_1
"@ | Out-File $testSourcePath -Encoding ascii

$hashTbl = @{'TOKEN_1'='abc';'TOKEN_2'='def';'TOKEN_3'='not used'}
@"
This is line 1
abc is on line 2
line 3 has def
abcabcabcabc
"@ | Out-File $testDestPath -Encoding ascii
$expected = Get-Content $testDestPath -Raw

Get-Content $testSourcePath | Update-Tokens $hashTbl | Set-Content $testDestPath -Encoding ascii

$results = Get-Content $testDestPath -Raw
Assert-Value "Update-Tokens" $results $expected


#############################################################
#
#    Report the results
#


if ($script:failedTests.Length -gt 0) {
    $script:failedTests | ForEach-Object { Write-Error $_ }
}
else {
    Write-Host "All tests succeeded."
}


#############################################################
#
#    Unload the modules
#


$dynamicModules | ForEach-Object { $_ | Remove-Module }

