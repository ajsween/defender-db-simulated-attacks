#!/bin/bash

# Azure SQL MI Deployment Script
# This script deploys the SQL Managed Instance infrastructure

set -e

# Variables
RESOURCE_GROUP_NAME="rg-d4sql-sims"
LOCATION="East US 2"
DEPLOYMENT_NAME="sqlmi-deployment-$(date +%Y%m%d-%H%M%S)"

echo "🚀 Starting Azure SQL Managed Instance deployment..."

# Login to Azure (if not already logged in)
echo "🔐 Checking Azure login status..."
if ! az account show &> /dev/null; then
    echo "Please log in to Azure..."
    az login
fi

# Get subscription ID from Azure CLI or environment variable
if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    if [ -z "$SUBSCRIPTION_ID" ]; then
        echo "❌ Could not determine subscription ID. Please set AZURE_SUBSCRIPTION_ID environment variable or ensure you're logged into Azure CLI."
        exit 1
    fi
    echo "📋 Using current subscription: $SUBSCRIPTION_ID"
else
    SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
    echo "📋 Using subscription from environment: $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Get current public IP
echo "🌐 Retrieving your current public IP address..."
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Failed to retrieve public IP address. Trying alternative method..."
    PUBLIC_IP=$(curl -s ipinfo.io/ip)
fi

if [ -z "$PUBLIC_IP" ]; then
    echo "❌ Could not retrieve public IP address. Please check your internet connection."
    exit 1
fi

echo "📍 Your current public IP: $PUBLIC_IP"

# Create resource group
echo "📁 Creating resource group: $RESOURCE_GROUP_NAME"
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION"

# Deploy Bicep template
echo "🏗️  Deploying Bicep template..."
echo "⚠️  Note: SQL Managed Instance deployment can take 3-6 hours to complete"
az deployment group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --template-file "main.bicep" \
    --parameters "@main.parameters.json" clientPublicIP="$PUBLIC_IP" \
    --name "$DEPLOYMENT_NAME" \
    --verbose

echo "✅ Deployment initiated successfully!"
echo "📊 You can monitor the deployment in the Azure Portal:"
echo "   https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/overview"

echo ""
echo "🔍 To check deployment status:"
echo "   az deployment group show --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME --query properties.provisioningState"

echo ""
echo "📝 Deployment details:"
echo "   Resource Group: $RESOURCE_GROUP_NAME"
echo "   Deployment Name: $DEPLOYMENT_NAME"
echo "   Location: $LOCATION"
echo "   SQL Admin Username: d4sqlsim"
echo "   Your Public IP: $PUBLIC_IP"
