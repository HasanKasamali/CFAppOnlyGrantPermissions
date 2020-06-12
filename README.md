# APP Only Grant Admin Permissions

Using a existing Service Principal to give other application API permissions

## Getting Started
The Azure CLI is used in preference to the PowerShell Az library as it is more idempotent and has better coverage.

## Manual Steps to Create the first App Registration
- Open https://portal.azure.com
- Go to App Registrations
- Click New Registration
    - Name: Azure API Registration
    - Supported Account types: Accounts in this organizational directory only
    - Redirect URI (Optional): Web https://localhost
    - Register
- Take note of the Application (client) ID and the Directory (tenant) ID.
- Click API Permissions
    - Add Permissions
        - Azure Active Directory Graph
            - Application Permissions
                - Application.ReadWrite.All
                - Add permissions
    - Grant Admin consent for tenant
- Click Certificates & secrets
    - New client secret
        - Description: AZ login Password
        - Expires: Never
    - Click Add
    - Take note of the secret


$tenant = ""
$appId = ""
$secret = ""

az login --service-principal --tenant $tenant --username $appId --password $secret --allow-no-subscriptions

