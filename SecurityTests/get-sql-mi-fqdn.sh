#!/bin/bash

# Get SQL MI FQDN Helper Script
# This script helps extract the SQL Managed Instance FQDN from Azure deployment

set -e

RESOURCE_GROUP_NAME="rg-d4sql-sims"

echo "🔍 Retrieving SQL Managed Instance FQDN..."

# Get subscription ID from Azure CLI or environment variable
if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null)
    if [ -z "$SUBSCRIPTION_ID" ]; then
        echo "❌ Could not determine subscription ID. Please set AZURE_SUBSCRIPTION_ID environment variable or ensure you're logged into Azure CLI."
        exit 1
    fi
else
    SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID" 2>/dev/null
fi

# Get the SQL MI name and FQDN
SQL_MI_NAME=$(az sql mi list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].name" -o tsv 2>/dev/null)
SQL_MI_FQDN=$(az sql mi list --resource-group "$RESOURCE_GROUP_NAME" --query "[0].fullyQualifiedDomainName" -o tsv 2>/dev/null)

if [ -z "$SQL_MI_FQDN" ]; then
    echo "❌ Could not retrieve SQL MI FQDN. Make sure the deployment is complete."
    echo "📋 Resource Group: $RESOURCE_GROUP_NAME"
    echo "📋 Subscription: $SUBSCRIPTION_ID"
    exit 1
fi

echo "✅ SQL Managed Instance Details:"
echo "   Name: $SQL_MI_NAME"
echo "   FQDN: $SQL_MI_FQDN"
echo ""
echo "🧪 To run brute force tests, use:"
echo "   ./test-brute-force.sh --host $SQL_MI_FQDN"
echo ""
echo "🧪 Example test commands:"
echo "   # Basic test with small wordlist"
echo "   ./test-brute-force.sh --host $SQL_MI_FQDN"
echo ""
echo "   # Test specific username with medium wordlist"
echo "   ./test-brute-force.sh --host $SQL_MI_FQDN --username d4sqlsim --wordlist medium"
echo ""
echo "   # Slower, stealthier test"
echo "   ./test-brute-force.sh --host $SQL_MI_FQDN --threads 5 --delay 3 --wordlist large"
