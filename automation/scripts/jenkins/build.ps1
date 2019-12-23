##################
### Build Datacastle/Citadel/MidmarketEndpoint
###
### To refine the build, add one of the below environment variables to your command line
### Variables are commented out for now and would need to investigate the usage.
##################
Param (
	[parameter(Mandatory=$true, HelpMessage="Usually FAST or NIGHTLY")] [string] [ValidateSet("FAST","NIGHTLY")] $BuildType,
	[parameter(Mandatory=$true, HelpMessage="Usually NightlyLite or NightlyFull")] [string]  [ValidateSet("NightlyLite","NightlyFull")] $TFSBuildType,
	[parameter(Mandatory=$true, HelpMessage="IP or FQHN of a Mac build machien to control")] [string]  $MacBuild,
	[parameter(Mandatory=$true, HelpMessage="Credentials for the Mac Build Machine")] [string]  $MacBuildUsername,
	[parameter(Mandatory=$true, HelpMessage="Credentials for the Mac Build Machine")] [string]  $MacBuildPassword,
	[parameter(HelpMessage="Index of the brand being built")] [int] $BuildBrandIndex = 0,
	[parameter(HelpMessage="CSV build flags to skip components or lengthy operations")] [string] $SkipComponentsString = "",
    [parameter(HelpMessage="RC, Nightly, CI or PR")] [string] [ValidateSet("RC","Nightly","CI","PR")] $BuildLevel = ""
)

$Env:BUILD_LEVEL = $BuildLevel
Write-Host '----- build.ps1 -----'
Write-Host "Env:BRANCH: $Env:BRANCH"
Write-Host "Env:BUILD_LEVEL: $Env:BUILD_LEVEL"
Write-Host "MacBuild: $MacBuild"
Write-Host "SkipComponents: <$SkipComponentsString>"
Write-Host '-----'

# Split the comma-delimited string arg into an array
$SkipComponents = $SkipComponentsString.replace(' ','').split(',')

[String []]$OptionalArgs = @()
if ($SkipComponents.Contains("SKIP_SERVER_OBFUSCATION") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING SERVER OBFUSCATION"
    $OptionalArgs += "DoNotObfusateVault=true"
    $OptionalArgs += "DoNotObfuscateQuickCache=true"
    $OptionalArgs += "DoNotObfuscateTools=true"
    $OptionalArgs += "DoNotObfuscateResetServer=true"
}

if ($SkipComponents.Contains("SKIP_CLIENT_OBFUSCATION") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING CLIENT OBFUSCATION"
    $OptionalArgs += "SkipClientObfuscation=true"
}

if ($SkipComponents.Contains("SKIP_LDAP_SYNC") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING LDAP SYNC"
    $OptionalArgs += "DoNotIncludeLDAPSync=true"
}

if ($SkipComponents.Contains("SKIP_QUICK_CACHE") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING Quick Cache"
    $OptionalArgs += "DoNotIncludeQuickCache=true"
}

if ($SkipComponents.Contains("SKIP_TOOLS") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING TOOLS"
    $OptionalArgs += "DoNotIncludeTools=true"
}

if ($SkipComponents.Contains("SKIP_SIGNING") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING SIGNING"
    $OptionalArgs += "DoNotIncludeSigning=true"
}

if ($SkipComponents.Contains("SKIP_SQL_EXPRESS") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING Vault Bootstrapper (branded and non-branded) SQL express"
    $OptionalArgs += "DoNotIncludeSQLExpress=true"
}

if ($SkipComponents.Contains("SKIP_MAC_CLIENT") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING Mac Client Build"
    $OptionalArgs += "DoNotIncludeMacClient=true"
    $RemoteResources = "artifacts.carb.lab"
} else {
    $RemoteResources = $MacBuild, 'artifacts.carb.lab'
}

if ($SkipComponents.Contains("SKIP_RESET_SERVER") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING Reset Server"
    $OptionalArgs += "DoNotIncludeResetServer=true"
}

if ($SkipComponents.Contains("SKIP_PASSPHRASE_CLIENT") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING BUILDING WITH PASSPHRASE CLIENT"
    $OptionalArgs += "DoNotIncludePassphraseClient=true"
}

if ($SkipComponents.Contains("SKIP_AZURE") -and $BuildLevel -eq "PR") {
    write-Host "SKIPPING Azure"
    $OptionalArgs += "DoNotIncludeAzure=true"
}

if ($SkipComponents.Contains("SKIP_PRECOMPILED_HELP") -and $BuildLevel -eq "PR") {
    write-Host "SKIPPING PreCompiled Help"
    $OptionalArgs += "DoNotIncludePrecompiledHelp=true"
}

if ($SkipComponents.Contains("SKIP_CLIENT") -and $BuildLevel -eq "PR") {
    Write-Host "SKIPPING Build Bootstrapper(client .exe)"
    $OptionalArgs += "DoNotBuildClients=true"
}

if ($BuildLevel -In "NIGHTLY","RC" -And -Not $SkipComponents.Contains("SKIP_CLIENT_BRANDING")) {
    Write-Host "BUILDING Client Branding"
    $OptionalArgs += "BuildAllClientBrands=true"
}

$working_directory= $ENV:WORKSPACE 

$cmd = "C:\program files\VisBuildPro9\visbuildcmd.exe"
$buildFile = "{0}\build\datacastle.bld" -f $working_directory
$logFile = """{0}\Build.log""" -f $working_directory


Write-Host $cmd $buildFile WORKING_DIRECTORY=$working_directory MACBUILD=$MacBuild MACBUILD_USER=$MacBuildUsername MACBUILD_PWD=$MacBuildPassword BUILD_TYPE=$BuildType TFSBUILDTYPE=$TFSBuildType OUTPUTSUBDIR=$BuildBrandIndex RUN_UNIT_TESTS_OBFUSCATED=false RUN_UNIT_TESTS=true TEST_TYPE=Minimum BUILD_BRAND_INDEX=$BuildBrandIndex @OptionalArgs /logfile $logFile /nologo /nooutput

& $cmd $buildFile WORKING_DIRECTORY=$working_directory MACBUILD=$MacBuild MACBUILD_USER=$MacBuildUsername MACBUILD_PWD=$MacBuildPassword BUILD_TYPE=$BuildType TFSBUILDTYPE=$TFSBuildType OUTPUTSUBDIR=$BuildBrandIndex RUN_UNIT_TESTS_OBFUSCATED=false RUN_UNIT_TESTS=true TEST_TYPE=Minimum BUILD_BRAND_INDEX=$BuildBrandIndex @OptionalArgs /logfile $logFile /nologo /nooutput
If ($LastExitCode -ne 0) {
    $errorFile = 'Failure.txt'
    If (Test-Path $errorFile) {Throw (Get-Content $errorFile)}
    Exit 1
}

### Collect build properties and generate a properties file
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$scriptDir\generate_build_properties.ps1"
