
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
