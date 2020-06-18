#https://graph.microsoft.com/v1.0/serviceprincipals/<servicePrincipalID>/appRoleAssignments
#https://docs.microsoft.com/en-us/graph/api/serviceprincipal-post-approleassignments?view=graph-rest-1.0&tabs=http


[CmdletBinding()]
param (
	[Parameter(Mandatory)]
	[string]
	$ApplicationName,
	[Parameter(Mandatory)]
	[string]
	$ParametersJsonFilePath,
	[Parameter()]
	[bool]
	$setPassword = $true
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Import-Module -Name:"$PSScriptRoot\AzCli" -Force -ArgumentList:@(
	$ErrorActionPreference,
	$InformationPreference,
	$VerbosePreference
)

$appReg = Set-AppRegistration -ApplicationName:$ApplicationName

if($setPassword){
	$appCredentials = Set-AppCredentials -AppId:$appReg.appId
}

$servicePrincipal = Set-ServicePrincipalForAppId -AppId:$appReg.appId

Remove-CurrentAppPermissions -AppId:$appReg.appId

Set-DelegatePermissions -ServicePrincipal:$servicePrincipal -ParametersJsonFilePath:$ParametersJsonFilePath

Set-ApplicationPermissions -ServicePrincipal:$servicePrincipal -ParametersJsonFilePath:$ParametersJsonFilePath

Write-Output $appCredentials