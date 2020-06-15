# App Registration - Create, Apply and Grant Permissions other App Registrations
Using an Application Registration to Create, Apply Permissions, and Grant Permissions to other application registrations.

## Getting Started
The Azure CLI is used in preference to the PowerShell Az library as it is more idempotent and has better coverage.

## (Automated) Steps to Create the First Application Registration the will Create, Apply and Grant others.
This is the initial setup to create a Application Registration, with the required permissions. This has to be created with an account that can actually grant permissions. (e.g., Application / Global Administrator)
- Ensure Azure CLI is installed. https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
- Log into AZ Cli (remove --allow-no-subscriptions if you ahve access to a subscription)
```ps
az login --allow-no-subscriptions
```
- Run .\Add-RegistrationAndGrantPermissions.ps1 using the AzureAPIRegistrationPermissions.json file.
```ps
.\Add-RegistrationAndGrantPermissions.ps1 -ApplicationName:"Azure API Registration" -ParametersJsonFilePath:'.\Data\AzureAPIRegistrationPermissions.json'
```
- You will receive a appId, tenant, and Password. Take note of these values.

## (Manual) Steps to Create the First Application Registration the will Create, Apply and Grant others.
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
                - Directory.ReadWrite.All
        - Microsoft Graph
            - Application Permissions
                - AppRoleAssignment.ReadWrite.All
                - Directory.ReadWrite.All
    - Grant Admin consent for tenant
- Click Certificates & secrets
    - New client secret
        - Description: Registration
        - Expires: Never
    - Click Add
    - Take note of the secret

## Create a login script for the App Registration

- Create a folder called Secrets
- Create a login.ps1 file inside
- Add the following script and replace values with your values of the "Azure API Registration"
```ps
$tenant = "[TenantId]"
$appId = "[appId]"
$secret = "[secret]"

az login --service-principal --tenant $tenant --username $appId --password $secret --allow-no-subscriptions
```
## Create a permission.json file
Provided in the Data folder is an [examplePermissions.json](.\data\examplePermissions.json) file. This shows you the structure of the JSON file.

Create an array for each type of API.

- Name: This is the AppDisplayName of the API Service Principal Permission, or the API Service Principal appId.
    - For example: "Microsoft Graph" or "00000003-0000-0000-c000-000000000000"
    - Find all in your tenant using the following az command
    ```ps
    az ad sp list --query "[].{appDisplayName:appDisplayName,appId:appId,objectId:objectId}" --all --output table
    ```
- DelegatePermissions: These are the names of the oAuth2Permission for the API. 
    - For example: "User.Read", "Contacts.Read"
    - Do not include in JSON file if no Delegate Permissions are required.
    - Find all in you tenant using the API Service Principal appId with the following az command
    ```ps
    #example with Microsoft Graph as the API Service Principal
    az ad sp show --id '00000003-0000-0000-c000-000000000000' --query "oauth2Permissions[].{displayName:userConsentDisplayName,value:value}" --output table
    ```
- ApplicationPermissions: These are the names of the AppRoles for the API.
    - For example: "Application.ReadWrite.All", "Directory.ReadWrite.All"
    - Do not include in JSON file if no Delegate Permissions are required.
    - Find all in your tenant using the API Service Principal appId with the following az command
    ```ps
    #example with Microsoft Graph as the API Service Principal
    az ad sp show --id '00000003-0000-0000-c000-000000000000' --query "appRoles[].{displayName:displayName,value:value}" --output table
    ```

Save this file in the Data Folder.

## Create App Registration using App Registration

### Login as the 'Azure API Registration'
- Run the following script
```ps
.\secrets\login.ps1
```
You should now be logged in as the Azure API Registration. This account is now setup to create, assign and Grant permissions.

### Run the script to create a new App Registration
- Run the following script
```ps
$ApplicationName = "[NameOfYourChoice]"
$PermissionsFile = ".\Data\[YourParameterFile].json"
.\Add-RegistrationAndGrantPermissions.ps1 -ApplicationName:$ApplicationName -ParametersJsonFilePath:$PermissionsFile
```

#TODO:
When I have time there will be a blog post at this site:
https://cann0nf0dder.wordpress.com