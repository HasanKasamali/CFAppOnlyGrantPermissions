param (
    [Parameter(Position = 0)]
    [string]
    $ErrorActionOverride = $(throw "You must supply an error action preference"),

    [Parameter(Position = 1)]
    [string]
    $InformationOverride = $(throw "You must supply an information preference"),

    [Parameter(Position = 2)]
    [string]
    $VerboseOverride = $(throw "You must supply a verbose preference")
)

$ErrorActionPreference = $ErrorActionOverride
$InformationPreference = $InformationOverride
$VerbosePreference = $VerboseOverride


function Get-APIPermissionsObject {
    param(
        [Parameter(Mandatory)]
        [string]
        $Name,
        [Parameter]
        [string[]]
        $DelegatePermissions,
        [Parameter]
        [string[]]
        $ApplicationPermissions
    )

    $obj = "" | Select-Object Name, DelegatePermissions, ApplicationPermissions
    $obj.Name = $Name,
    $obj.DelegatePermissions = $DelegatePermissions
    $obj.ApplicationPermissions = $ApplicationPermissions

    Write-Output $obj
}
function Invoke-AzCommand {
    param(
        # The command to execute
        [Parameter(Mandatory)]
        [string]
        $Command,

        # Output that overrides displaying the command, e.g. when it contains a plain text password
        [string]
        $Message = $Command
    )

    Write-Information -MessageData:$Message

    # Az can output WARNINGS on STD_ERR which PowerShell interprets as Errors
    $CurrentErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue" 

    Invoke-Expression -Command:$Command | ConvertFrom-Json
    $ExitCode = $LastExitCode
    Write-Information -MessageData:"Exit Code: $ExitCode"
    $ErrorActionPreference = $CurrentErrorActionPreference

    switch ($ExitCode) {
        0 {
            Write-Debug -Message:"Last exit code: $ExitCode"
        }
        default {
            throw $ExitCode
        }
    }
}

function  Set-AppRegistration {
    param(
        # The command to execute
        [Parameter(Mandatory)]
        [string]
        $ApplicationName
    )

    Write-Information -MessageData:"Creating/Updating the $ApplicationName App Registration..."
    $appReg = Invoke-AzCommand -Command:"az ad app create --display-name '$ApplicationName'"

    Write-Output $appReg
}

function Set-AppCredentials {
    param(
        [Parameter(Mandatory)]
        [string]
        $AppId,
        [ValidateLength(0, 16)]
        [Parameter()]
        [string]
        $Description = "Registration",
        [Parameter()]
        [securestring]
        $SecureSecret
    )

    Write-Information -MessageData:"Assigning Password to description '$Description'..."
    if ($SecureSecret) {
        $secret = ConvertFrom-SecureString -SecureString:$SecureSecret -AsPlainText
        $appCredentials = Invoke-AzCommand -Command:"az ad app credential reset --id $AppId --credential-description '$Description' --password $secret --end-date 2299-12-31"
    }
    else {
        $appCredentials = Invoke-AzCommand -Command:"az ad app credential reset --id $AppId --credential-description '$Description' --end-date 2299-12-31"
    }
  
    Write-Output $appCredentials
}

function Set-ServicePrincipalForAppId {
    param(
        [Parameter(Mandatory)]
        [string]
        $AppId
    )

    Write-Information -MessageData:"Checking if the Service Principal exists for the $AppId..."
    $servicePrincipal = Invoke-AzCommand -Command:"az ad sp list --spn $AppId"
    if ($servicePrincipal.Length -eq 0) {
        Write-Information -MessageData:"Creating the Service Principal for the $AppId..."
        $servicePrincipal = Invoke-AzCommand -Command:"az ad sp create --id $AppId"
    }

    Write-Output $servicePrincipal
}

function Set-DelegatePermissions {
    param(
        [Parameter(Mandatory)]
        [object]
        $ServicePrincipal,
        [Parameter(Mandatory)]
        [string]
        $ParametersJsonFilePath   
    )

    Get-Content -Raw -Path $ParametersJsonFilePath | ConvertFrom-Json | ForEach-Object {
        $APIPerms = $PSItem
        $apiUrl = "https://graph.microsoft.com/v1.0/oauth2Permissiongrants"
        $permsNames = @()
       
        if (-not $APIPerms.DelegatePermissions) {
            return
        }

        Write-Information -MessageData:"Getting Service Principal for '$($APIPerms.Name)'..."
        $APIServicePrincipal = Invoke-AzCommand -Command:"az ad sp list --query ""[?appDisplayName=='$($APIPerms.Name)' || appId=='$($APIPerms.Name)']"" --all"

        $APIPerms.DelegatePermissions | ForEach-Object {
            $delegatePerms = $PSItem
           
            $delegatePermInfo = Invoke-AzCommand -Command:"az ad sp show --id $($APIServicePrincipal.appId) --query ""oauth2Permissions[?value=='$delegatePerms']"""
            $permsNames += $delegatePermInfo.value

            Write-Information -MessageData:"Setting the App Registration Permission '$($ServicePrincipal.appDisplayName)' with '$($delegatePermInfo.value)'..."
            Invoke-AzCommand -Command:"az ad app permission add --id $($ServicePrincipal.appId) --api $($APIServicePrincipal.appId) --api-permissions $($delegatePermInfo.id)=Scope"
        }

        $existing = Invoke-AzCommand -Command:"az ad app permission list-grants --filter ""clientId eq '$($ServicePrincipal.objectId)' and consentType eq 'AllPrincipals' and resourceId eq '$($APIServicePrincipal.objectId)'"" " | Select-Object -First 1
        
        $tokenResponse = Invoke-AzCommand -Command:"az account get-access-token --resource-type ms-graph" 
        
        $method = "POST"
        $uniquePerms = $permsNames | Sort-Object | Get-Unique
        
        $body = @{
            clientId    = $($servicePrincipal.objectId)
            consentType = "AllPrincipals"
            principalId = $null
            resourceId  = $($APIServicePrincipal.objectId)
            scope       = $($uniquePerms -join " ")
            startTime   = "0001-01-01T00:00:00Z"
            expiryTime  = "2299-12-31T00:00:00Z"
        }

        if($existing){
            $method = "PATCH"
            #Please note app permissions cannot delete, only a user can do that. Workaround patch with no perms.
            Write-Information "Updating existing delegate grants..."
          
            $apiUrl += "/$($existing.objectId)"
            $body = @{
			    scope = $($uniquePerms -join " ")
		    } 
         }
         
        Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($tokenResponse.accessToken)" }  -Method $method -Body $($body | ConvertTo-Json) -ContentType "application/json" | ConvertTo-Json

    }
}

function Set-ApplicationPermissions {
    param(
        [Parameter(Mandatory)]
        [object]
        $ServicePrincipal,
        [Parameter(Mandatory)]
        [string]
        $ParametersJsonFilePath   
    )
 
    Remove-CurrentServicePrincipalGrants -ServicePrincipalObjectId:$ServicePrincipal.objectId

    Get-Content -Raw -Path $ParametersJsonFilePath | ConvertFrom-Json | ForEach-Object {
        $APIPerms = $PSItem
        $apiUrl = "https://graph.microsoft.com/v1.0/servicePrincipals"
             
        if (-not $APIPerms.ApplicationPermissions) {
            return
        }

        $tokenResponse = Invoke-AzCommand -Command:"az account get-access-token --resource-type ms-graph" 

        Write-Information -MessageData:"Getting Service Principal for $($APIPerms.Name)..."
        $APIServicePrincipal = Invoke-AzCommand -Command:"az ad sp list --query ""[?appDisplayName=='$($APIPerms.Name)' || appId=='$($APIPerms.Name)']"" --all"

        $APIPerms.ApplicationPermissions | ForEach-Object {
            $appPerms = $PSItem
           
            $appPermInfo = Invoke-AzCommand -Command:"az ad sp show --id $($APIServicePrincipal.appId) --query ""appRoles[?value=='$appPerms']"""
            
            Write-Information -MessageData:"Setting the App Registration Permission '$($ServicePrincipal.appDisplayName)' with '$($appPermInfo.value)'..."
            Invoke-AzCommand -Command:"az ad app permission add --id $($ServicePrincipal.appId) --api $($APIServicePrincipal.appId) --api-permissions $($appPermInfo.id)=Role"

            $body = @{
                principalId = $ServicePrincipal.objectId
                resourceId  = $APIServicePrincipal.objectId
                appRoleId   = $appPermInfo.id
            }

            $appRoleAssignmentUrl = "$apiUrl/$($ServicePrincipal.objectId)/appRoleAssignments"
           
            Invoke-RestMethod -Uri $appRoleAssignmentUrl -Headers @{Authorization = "Bearer $($tokenResponse.accessToken)" }  -Method POST -Body $($body | ConvertTo-Json) -ContentType "application/json" | ConvertTo-Json
        }
    }
}

function Remove-CurrentAppPermissions {
    param(
        [Parameter(Mandatory)]
        [string]
        $AppId
    )
    
    Write-Information -MessageData: "Getting existing permissions for AppID $AppId..."
    $currentPermissionCollection = @(Invoke-AzCommand -Command:"az ad app permission list --id $AppId")
    
    Write-Information -MessageData:"Removing all existing app permissions..."
    $currentPermissionCollection | ForEach-Object {
        $permission = $PSItem
        if($null -ne $permission.resourceAppId){ 
        Invoke-AzCommand -Command:"az ad app permission delete --id $AppId --api $($permission.resourceAppId)"
        }
    }

}

function Remove-CurrentServicePrincipalGrants {
 
    param(
        [Parameter(Mandatory)]
        [string]
        $ServicePrincipalObjectId
    )
    
    $tokenResponse = Invoke-AzCommand -Command:"az account get-access-token --resource-type ms-graph" 
    Write-Information -MessageData:"Getting all existing Service Principal Grants for $ServicePrincipalObjectId..."

    $apiUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$ServicePrincipalObjectId/appRoleAssignments"
    
    $appRoleAssignmentCollection = (Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($tokenResponse.accessToken)" }  -Method GET -Body $($body | ConvertTo-Json) -ContentType "application/json" | ConvertTo-Json).value
    
    if($appRoleAssignmentCollection.Count -eq 0){return}
        
    $appRoleAssignmentCollection | Foreach-Object {
        $appRoleAssignment = $PSItem

        Write-Information -MessageData:"Removing $servicePrincipalObjectID grant for appRoleId:$($appRoleAssignment.appRoleId) for resource:$($appRoleAssignment.resourceDisplayName)"
        $deleteApiUrl = "$apiUrl/$($appRoleAssignment.id)"
        Invoke-RestMethod -Uri $deleteApiUrl -Headers @{Authorization = "bearer $($tokenResponse.accessToken)"} -Method Delete -ContentType "application/json"
    }
}