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


function Get-APIPermissionsObject{
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
        [ValidateLength(0,16)]
        [Parameter()]
        [string]
        $Description = "Registration",
        [Parameter()]
        [securestring]
        $SecureSecret
    )

    Write-Information -MessageData:"Assigning Password to description '$Description'..."
	if($SecureSecret)
    {
        $secret = ConvertFrom-SecureString -SecureString:$SecureSecret -AsPlainText
        $appCredentials = Invoke-AzCommand -Command:"az ad app credential reset --id $($appReg.appId) --credential-description '$Description' --password $secret --end-date 2299-12-31"
    }else{
        $appCredentials = Invoke-AzCommand -Command:"az ad app credential reset --id $($appReg.appId) --credential-description '$Description' --end-date 2299-12-31"
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
    $servicePrincipal = Invoke-AzCommand -Command:"az ad sp list --spn $($appReg.appId)"
    if ($servicePrincipal.Length -eq 0) {
        Write-Information -MessageData:"Creating the Service Principal for the $AppId..."
        $servicePrincipal = Invoke-AzCommand -Command:"az ad sp create --id $($appReg.appId)"
    }

    Write-Output $servicePrincipal
}

