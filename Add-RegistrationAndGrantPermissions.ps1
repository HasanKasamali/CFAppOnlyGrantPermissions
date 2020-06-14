#https://winsmarts.com/how-to-grant-admin-consent-to-an-api-programmatically-e32f4a100e9d

#https://graph.microsoft.com/beta/serviceprincipals/<servicePrincipalID>/appRoleAssignments
#https://graph.microsoft.com/beta/serviceprincipals/<servicePrincipalID>/appRoleAssignedTo

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
	$resetPassword = $true
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Import-Module -Name:"$PSScriptRoot\AzCli" -Force -ArgumentList:@(
	$ErrorActionPreference,
	$InformationPreference,
	$VerbosePreference
)

$appReg = Set-AppRegistration -ApplicationName:$ApplicationName

if($resetPassword){
	Set-AppCredentials -AppId:$appReg.Id
}

$servicePrincipal = Set-ServicePrincipalForAppId -AppId:$appReg.Id



$jsondata = Get-Content -Raw -Path $ParametersJsonFilePath | ConvertFrom-Json
$jsonData | ForEach-Object {
	$apiUrl = "https://graph.microsoft.com/beta/oauth2PermissionGrants"
	$permsNames = @()
	$Tokenresponse = Invoke-AzCommand -Command:"az account get-access-token --resource-type ms-graph" 
	$APIPerms = $PSItem

	$APIServicePrincipal = Invoke-AzCommand -Command:"az ad sp list --query ""[?appDisplayName=='$($APIPerms.Name)' || appId=='$($APIPerms.Name)']"" --all"
	Write-Information -MessageData: "Getting existing permissions first for AppID $($appReg.AppId)..."
	$currentPermissions - @(Invoke-AzCommand -Command:"az ad app permission list --id $($appReg.AppId)")

	if ($APIPerms.ApplicationPermissions) {
		$APIPerms.ApplicationPermissions | ForEach-Object {
			$appPerms = $PSItem 
			$appPermInfo = Invoke-AzCommand -Command:"az ad sp show --id $($APIServicePrincipal.appId) --query ""appRoles[?value=='$appPerms']"""

			$permsNames += $appPermInfo.value

			$existingPermissions = $currentPermissions | Where-Object { $PSItem.resourceAppId -eq $APIServicePrincipal.appId } |
			Select-Object -ExpandProperty "resourceAccess" |
			Where-Object { $PSItem.id -eq $appPermInfo.id }
			
			if (-not $existingPermissions) {
				Invoke-AzCommand -Command:"az ad app permission add --id $($appReg.AppId) --api $($APIServicePrincipal.appId) --api-permissions $($appPermInfo.id)=Role"
			}
		}
	}

	if ($APIPerms.DelegatePermissions) {
		$APIPerms.DelegatePermissions | ForEach-Object {
			$delegatePerms = $PSItem
			$delegatePermInfo = Invoke-AzCommand -Command:"az ad sp show --id $($APIInfo.appId) --query ""oauth2Permissions[?value=='$delegatePerms']"""
		
			$permsNames += $delegatePermInfo.value

			$existingPermissions = $currentPermissions | Where-Object { $PSItem.resourceAppId -eq $APIServicePrincipal.appId } |
			Select-Object -ExpandProperty "resourceAccess" |
			Where-Object { $PSItem.id -eq $appPermInfo.id }
			
			if (-not $existingPermissions) {
				Invoke-AzCommand -Command:"az ad app permission add --id $($appReg.AppId) --api $($APIServicePrincipal.appId) --api-permissions $($delegatePermInfo.id)=Scope"
			}
		}
	}

	$uniquePerms = $permsNames | Sort-Object | Get-Unique

	$method = "POST"
	
	$body = @{
		clientId    = $($servicePrincipal.objectId)
		consentType = "AllPrincipals"
		principalId = $null
		resourceId  = $($APIServicePrincipal.objectId)
		scope       = $($uniquePerms -join " ")
		startTime   = "0001-01-01T00:00:00Z"
		expiryTime  = "2299-12-31T00:00:00Z"
	}

	$existing = Invoke-AzCommand -Command:"az ad app permission list-grants --filter ""clientId eq '$($servicePrincipal.objectId)' and consentType eq 'AllPrincipals' and resourceId eq '$($APIServicePrincipal.objectId)'"" " | Select-Object -First 1

	if ($existing) {
		$method = "PATCH"
		$uniquePerms += $existing.scope -split " "
		$uniquePerms = $uniquePerms | Sort-Object | Get-Unique
		
		$apiUrl += "/$($existing.objectId)"
		$body = @{
			scope = $($uniquePerms -join " ")
		}
	}
	
	Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($Tokenresponse.accessToken)" }  -Method POST -Body $($body | ConvertTo-Json) -ContentType "application/json" | ConvertTo-Json
}

$appCredentials