#!/bin/bash
APPNAME="awx-ansible-service-principal"
MSGRAPHAPPID="00000003-0000-0000-c000-000000000000"
PERMISSIONS=(
    "Policy.Read.All"
    "Policy.ReadWrite.ConditionalAccess"
)

# Create app if not exists
echo "Check if app with name $APPNAME already exists"
APPID=$(az ad app list --display-name $APPNAME --query [].appId -o tsv)
[ -z $APPID ] && az ad app create --display-name $APPNAME &&
    APPID=$(az ad app list --display-name $APPNAME --query [].appId -o tsv) &&
    az ad sp create --id $APPID ||
echo "Found application with id $APPID"

# Get permission ids
# 'az ad sp show --id $MSGRAPHAPPID --query "appRoles[*][value,id,allowedMemberTypes]" -o table' list all available approles/permissions
echo "Look for needed permission ids"
PERMISSION_IDS=()
for permission in ${PERMISSIONS[@]}
do
    id=$(az ad sp show --id $MSGRAPHAPPID --query "appRoles[?value=='$permission'].id" -o tsv)
    echo "Add id $id for $permission to list"
    PERMISSION_IDS+=($id)
done

# Apply permission ids to app
for permission_id in ${PERMISSION_IDS[@]}
do
    az ad app permission add --id $APPID --api $MSGRAPHAPPID --api-permissions "$permission_id=Role" --only-show-errors
    az ad app permission grant --id $APPID --api $MSGRAPHAPPID #--scope Policy.Read.All
done
echo "Grant applications permission through admin-consent (needed when used in application context)"
az ad app permission admin-consent --id $APPID

# New secret for app
echo "Use following variables for playbook, don't store them anywhere else! :" && echo ""
az ad app credential reset --id $APPID --query "{app_id:appId,app_secret:password,tenant_name_id:tenant}" --only-show-errors -o yaml