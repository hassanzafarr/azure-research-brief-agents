#!/usr/bin/env bash
set -euo pipefail

github_repo=${1:?Usage: scripts/bootstrap-azure.sh OWNER/REPO [azure-region] [project-name]}
location=${2:-westeurope}
project=${3:-research-brief}
if [[ ! "$github_repo" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+$ || ! "$project" =~ ^[a-z][a-z0-9-]{2,31}$ ]]; then
  printf 'Provide an owner/repo and a 3–32 character lowercase Azure project name.\n' >&2
  exit 2
fi

subscription_id=$(az account show --query id -o tsv)
tenant_id=$(az account show --query tenantId -o tsv)
app_group="rg-$project"
state_group="rg-$project-state"
digest=$(printf '%s' "$subscription_id/$state_group" | sha256sum)
state_account="stbrief${digest:0:16}"
identity="github-deploy"

subject=${GITHUB_OIDC_SUBJECT:-}
if [[ -z "$subject" ]]; then
  repo_metadata=$(gh api "repos/$github_repo" --jq '[.owner.login, .owner.id, .name, .id, .created_at] | @tsv')
  IFS=$'\t' read -r repo_owner owner_id repo_name repo_id created_at <<<"$repo_metadata"
  if [[ "${created_at:0:10}" > 2026-07-15 ]]; then
    subject="repo:$repo_owner@$owner_id/$repo_name@$repo_id:ref:refs/heads/main"
  else
    subject="repo:$repo_owner/$repo_name:ref:refs/heads/main"
  fi
fi

ensure_group() {
  local group=$1
  local owner group_project
  if [[ "$(az group exists --name "$group" -o tsv)" == true ]]; then
    owner=$(az group show --name "$group" --query tags.github_repository -o tsv)
    group_project=$(az group show --name "$group" --query tags.project -o tsv)
    if [[ "$owner" == "$github_repo" ]]; then
      return
    fi
    if [[ -z "$owner" && "$group_project" == research-brief-agents ]]; then
      az group update --name "$group" --set "tags.github_repository=$github_repo" --output none
    else
      printf 'Resource group %s exists and is not tagged for %s. Choose a different project name.\n' \
        "$group" "$github_repo" >&2
      exit 1
    fi
  else
    az group create --name "$group" --location "$location" \
      --tags "project=research-brief-agents" "github_repository=$github_repo" --output none
  fi
}

for provider in Microsoft.App Microsoft.ContainerRegistry Microsoft.ManagedIdentity Microsoft.OperationalInsights Microsoft.Storage; do
  az provider register --namespace "$provider" --wait --output none
done

ensure_group "$app_group"
ensure_group "$state_group"

az storage account create --name "$state_account" --resource-group "$state_group" \
  --location "$location" --sku Standard_LRS --kind StorageV2 --https-only true \
  --min-tls-version TLS1_2 --allow-blob-public-access false --allow-shared-key-access false --output none
az storage account blob-service-properties update --account-name "$state_account" \
  --resource-group "$state_group" --enable-versioning true --output none
state_id=$(az storage account show --name "$state_account" --resource-group "$state_group" --query id -o tsv)

# Use ARM to create the state container so the bootstrap operator needs no blob data role.
az rest --method put \
  --url "https://management.azure.com$state_id/blobServices/default/containers/tfstate?api-version=2023-05-01" \
  --body '{"properties":{"publicAccess":"None"}}' --output none

az identity create --name "$identity" --resource-group "$app_group" --location "$location" --output none
client_id=$(az identity show --name "$identity" --resource-group "$app_group" --query clientId -o tsv)
principal_id=$(az identity show --name "$identity" --resource-group "$app_group" --query principalId -o tsv)
az identity federated-credential create --name github-main --identity-name "$identity" \
  --resource-group "$app_group" --issuer 'https://token.actions.githubusercontent.com' \
  --subject "$subject" --audiences api://AzureADTokenExchange --output none

app_scope="/subscriptions/$subscription_id/resourceGroups/$app_group"
az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
  --role Contributor --scope "$app_scope" --output none
az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
  --role AcrPush --scope "$app_scope" --output none
az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
  --role 'Storage Blob Data Contributor' --scope "$state_id/blobServices/default/containers/tfstate" --output none

# Terraform can manage the app's AcrPull grant without authority to assign other roles.
condition=$(cat <<'CONDITION'
((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'}))
 OR (@Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {7f951dda-4ed3-4680-a7ca-43fe172d538d}))
AND
((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'}))
 OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {7f951dda-4ed3-4680-a7ca-43fe172d538d}))
CONDITION
)
az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
  --role 'Role Based Access Control Administrator' --scope "$app_scope" \
  --condition "$condition" --condition-version 2.0 --output none

# These identifiers are repository variables. The last one enables deployment.
printf 'AZURE_TENANT_ID=%s\n' "$tenant_id"
printf 'AZURE_SUBSCRIPTION_ID=%s\n' "$subscription_id"
printf 'AZURE_RESOURCE_GROUP=%s\n' "$app_group"
printf 'AZURE_STATE_ACCOUNT=%s\n' "$state_account"
printf 'AZURE_CLIENT_ID=%s\n' "$client_id"
