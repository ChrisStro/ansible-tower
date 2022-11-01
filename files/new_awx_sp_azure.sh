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
[ -z $APPID ] &&
    APPID=$(az ad app create --display-name $APPNAME --query appId -o tsv) &&
    az ad sp create --id $APPID -o yaml ||
(echo "Found application with id $APPID. Script cancel here"; exit 1)

# Get permission ids
# 'az ad sp show --id $MSGRAPHAPPID --query "appRoles[*][value,id,allowedMemberTypes]" -o table' list all available approles/permissions
echo -e "\nLook for needed permission ids\n"
PERMISSION_IDS=()
for permission in ${PERMISSIONS[@]}
do
    id=$(az ad sp show --id $MSGRAPHAPPID --query "appRoles[?value=='$permission'].id" -o tsv)
    echo -e "Add id $id for $permission to list\n"
    PERMISSION_IDS+=($id)
done

# Apply permission ids to app
echo "Application Name  : $APPNAME"
echo -e "Application ID    : $APPID\n"

INDEXOF=0
for permission_id in ${PERMISSION_IDS[@]}
do
    echo "Add permission ${PERMISSIONS[$INDEXOF]} to $APPNAME"
    az ad app permission add --id $APPID --api $MSGRAPHAPPID --api-permissions "$permission_id=Role" --only-show-errors -o yaml
    echo ""
    az ad app permission grant --id $APPID --api $MSGRAPHAPPID --scope ${PERMISSIONS[$INDEXOF]} -o yaml
    echo ""
    ((INDEXOF++))
done

echo "Grant applications permission through admin-consent (needed when used in application context)"
echo "We will wait 30 seconds before continuing (MS Graph sometimes takes a little time)"
sleep 30
echo "run: 'az ad app permission admin-consent --id $APPID'"
az ad app permission admin-consent --id $APPID

# New secret for app
echo "Use following variables for playbook, don't store them anywhere else! :" && echo ""
az ad app credential reset --id $APPID --query "{tenant_name_id:tenant,app_id:appId,app_secret:password}" --only-show-errors -o yaml

echo -e "--------------------------AWX/Tower Tip--------------------------
Does NOT work in AWX/Tower template:
app_secret: !vault |
          \$ANSIBLE_VAULT;1.1;AES256
          386463383536613....


Store encrypted variables in an INVENTORY using the following syntax:
app_secret:
  __ansible_vault: |
          \$ANSIBLE_VAULT;1.1;AES256
          386463383536613.....
"