
$AccessToken = az account get-access-token --resource-type ms-graph | ConvertFrom-Json

#objectID of the service Principal
$servicePrincipalId = "e6f44a68-577a-4eef-90ca-6a327af0eaea"
#Graph API ObjectID
$resourceId = "a364e801-205f-4947-b3cb-8093e1e44b76"
#RoleID for Directory.Read.All
$appRoleId = "7ab1d382-f21e-4acd-a863-ba3e13f7da61"

$method = "POST"
	
$body = @{
    principalId = $servicePrincipalId
    resourceId  = $resourceId
    appRoleId   = $appRoleId
}

$apiUrl = "https://graph.microsoft.com/beta/servicePrincipals/$servicePrincipalId/appRoleAssignments"

Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization = "Bearer $($AccessToken.accessToken)" }  -Method POST -Body $($body | ConvertTo-Json) -ContentType "application/json" | ConvertTo-Json
