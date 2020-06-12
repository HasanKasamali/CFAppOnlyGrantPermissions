
$perms = @(
    @{
        Name = "Microsoft Graph"
        DelegatePermissions = @("User.Read")
        ApplicationPermissions = @("Directory.Read.All","Sites.Read.All")
    },
    @{
        Name = "Windows Azure Active Directory"
        DelegatePermissions = @("User.Read","Group.Read.All")
        Application = @("Directory.Read.All")
    }
    @{
        Name = "Office 365 SharePoint Online"
        DelegatePermissions = @()
        Application = @("Sites.FullControl.All", "TermStore.Read.All", "User.Read.All")
    }
)


[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ApplicationName,
    [Parameter]
    [object]
    $Parameters
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Import-Module -Name:"$PSScriptRoot\AzCli" -Force -ArgumentList:@(
    $ErrorActionPreference,
    $InformationPreference,
    $VerbosePreference
)

Write-Information -MessageData:"Creating the $ApplicationName App Registration..."
$AppReg = Invoke-AzCommand -Command:"az ad app create --display-name '$ApplicationName'"
$Credentials = Invoke-AzCommand -Command:"az ad app credential reset --id $($AppReg.appId) --credential-description 'Registration' --end-date 2299-12-31"

Write-Information -MessageData:"Checking if the Service Principal exists for the $ApplicationName App Registration..."
$ServicePrincipalList = az ad sp list --spn $($AppRegistration.appId) | ConvertFrom-Json
if ($ServicePrincipalList.Length -eq 0) {
    Write-Information -MessageData:"Creating the Service Principal for the $ApplicationName App Registration"
    $ServicePrincipal = Invoke-AzCommand -Command:"az ad sp create --id $($AppReg.appId)"
}


#Permissions
$Name = "Microsoft Graph"
$graph = az ad sp list --query "[?appDisplayName=='Microsoft Graph']" --all | ConvertFrom-Json
#Application Permission
$appGroupReadAll = az ad sp show --id $graph.appId --query "oauth2Permissions[?value=='Group.Read.All']" | ConvertFrom-Json
#User Permission
$userGroupReadAll = az ad sp show --id $graph.appId --query "appRoles[?value=='Group.Read.All']" | ConvertFrom-Json

#Example working.
$Tokenresponse = az account get-access-token --resource-type ms-graph | ConvertFrom-Json

$AppRegistration = az ad app create --display-name 'Paul Demo' | ConvertFrom-Json
    
$ServicePrincipalList = az ad sp list --spn $($AppRegistration.appId) | ConvertFrom-Json
if ($ServicePrincipalList.Length -eq 0) {
    az ad sp create --id $($AppRegistration.appId)
}

$GraphServicePrincipal =  az ad sp list --filter "appId eq '00000002-0000-0000-c000-000000000000'" | ConvertFrom-Json

$directoryReadAll = $GraphServicePrincipal.oauth2Permissions | Where-Object { $_.value -eq "Directory.Read.All" } 
az ad app permission add --id "$($AppRegistration.AppId)" --api "$($GraphServicePrincipal.appId)" --api-permissions "$($directoryReadAll.id)=Scope"

$AppServicePrincipal = az ad sp list --filter "appId eq '$($AppRegistration.appId)'" | ConvertFrom-Json


$body = @{
    clientId    = $($AppServicePrincipal.objectId)
    consentType = "AllPrincipals"
    principalId = $null
    resourceId  = $($GraphServicePrincipal.objectId)
    scope       = "Directory.Read.All"
    startTime   = "2019-10-19T10:37:00Z"
    expiryTime  = "2019-10-19T10:37:00Z"
}

$apiUrl = "https://graph.microsoft.com/beta/oauth2PermissionGrants"

$output = Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($Tokenresponse.accessToken)" }  -Method POST -Body $($body | ConvertTo-Json) -ContentType "application/json" | ConvertTo-Json
<# 
"requiredResourceAccess": [
		{
            "Microsoft Graph"
			"resourceAppId": "00000003-0000-0000-c000-000000000000",
			
		},
		{
            "Windows Azure Active Directory"
			"resourceAppId": "00000002-0000-0000-c000-000000000000",
			"resourceAccess": [
				{
					"id": "1cda74f2-2616-4834-b122-5cb1b07f8a59",
					"type": "Role"
				}
			]
		},
		{
            "Office 365 SharePoint Online"
			"resourceAppId": "00000003-0000-0ff1-ce00-000000000000",
			"resourceAccess": [
				{
					"id": "678536fe-1083-478a-9c59-b99265e6b0d3",
					"type": "Role"
				}
			]
		},
		{
            "Office 365 Management APIs"
			"resourceAppId": "c5393580-f805-4401-95e8-94b7a6ef2fc2",
			"resourceAccess": [
				{
					"id": "594c1fb6-4f81-4475-ae41-0c394909246c",
					"type": "Role"
				}
			]
		},
		{
            "Common Data Service" #Dyanmics
			"resourceAppId": "00000007-0000-0000-c000-000000000000",
			"resourceAccess": [
				{
					"id": "78ce3f0f-a1ce-49c2-8cde-64b5c0896db4",
					"type": "Scope"
				}
			]
		},
		{
            "Power BI Service"
			"resourceAppId": "00000009-0000-0000-c000-000000000000",
			"resourceAccess": [
				{
					"id": "654b31ae-d941-4e22-8798-7add8fdf049f",
					"type": "Role"
				}
			]
		},
		
	], #>