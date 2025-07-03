#!/usr/bin/env bash

# Azure SQL MI Deployment Script
# This script deploys the SQL Managed Instance infrastructure

set -e

# Check for test mode
if [[ "$1" == "--test-params" ]]; then
    TEST_MODE=true
    echo "🧪 Running in parameter creation test mode"
else
    TEST_MODE=false
fi

# Function to validate password complexity
validate_password() {
    local password="$1"
    local errors=()
    
    # Check length (minimum 12 characters)
    if [ ${#password} -lt 12 ]; then
        errors+=("Password must be at least 12 characters long")
    fi
    
    # Check for uppercase letter
    if ! [[ "$password" =~ [A-Z] ]]; then
        errors+=("Password must contain at least one uppercase letter")
    fi
    
    # Check for lowercase letter
    if ! [[ "$password" =~ [a-z] ]]; then
        errors+=("Password must contain at least one lowercase letter")
    fi
    
    # Check for digit
    if ! [[ "$password" =~ [0-9] ]]; then
        errors+=("Password must contain at least one digit")
    fi
    
    # Check for special character
    if ! [[ "$password" =~ [^a-zA-Z0-9] ]]; then
        errors+=("Password must contain at least one special character")
    fi
    
    # Check for forbidden characters/patterns
    if [[ "$password" =~ [\"\'\\] ]]; then
        errors+=("Password cannot contain quotes or backslashes")
    fi
    
    # Check if it contains admin username
    if [[ "$password" =~ [Aa][Dd][Mm][Ii][Nn] ]] || [[ "$password" =~ [Ss][Qq][Ll] ]]; then
        errors+=("Password cannot contain 'admin' or 'sql'")
    fi
    
    if [ ${#errors[@]} -eq 0 ]; then
        return 0
    else
        printf "❌ Password validation failed:\n"
        for error in "${errors[@]}"; do
            printf "   • %s\n" "$error"
        done
        return 1
    fi
}

# Function to create main.parameters.json
create_parameters_file() {
    echo "📝 main.parameters.json not found. Creating it now..."
    echo ""
    echo "🔐 PASSWORD REQUIREMENTS:"
    echo "   • At least 12 characters long"
    echo "   • Must contain uppercase letters (A-Z)"
    echo "   • Must contain lowercase letters (a-z)"
    echo "   • Must contain digits (0-9)"
    echo "   • Must contain special characters (!@#$%^&*)"
    echo "   • Cannot contain quotes, backslashes, 'admin', or 'sql'"
    echo ""
    
    # Get password with validation
    while true; do
        echo -n "Enter a complex password for SQL Admin: "
        read -s password
        echo ""
        
        if validate_password "$password"; then
            echo "✅ Password meets complexity requirements"
            break
        fi
        echo ""
    done
    
    echo ""
    echo "🌍 SELECT AZURE REGION:"
    echo "   1) East US"
    echo "   2) East US 2"
    echo "   3) West US"
    echo "   4) West US 2"
    echo "   5) West US 3"
    echo "   6) Central US"
    echo "   7) North Central US"
    echo "   8) South Central US"
    echo "   9) West Central US"
    echo ""
    
    while true; do
        echo -n "Select region (1-9): "
        read region_choice
        
        case $region_choice in
            1) azure_region="East US"; break ;;
            2) azure_region="East US 2"; break ;;
            3) azure_region="West US"; break ;;
            4) azure_region="West US 2"; break ;;
            5) azure_region="West US 3"; break ;;
            6) azure_region="Central US"; break ;;
            7) azure_region="North Central US"; break ;;
            8) azure_region="South Central US"; break ;;
            9) azure_region="West Central US"; break ;;
            *) echo "❌ Invalid selection. Please choose 1-9."; continue ;;
        esac
    done
    
    echo "✅ Selected region: $azure_region"
    
    # Create the parameters file
    cat > main.parameters.json << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "sqlAdminPassword": {
      "value": "$password"
    },
    "location": {
      "value": "$azure_region"
    }
  }
}
EOF
    
    echo "✅ main.parameters.json created successfully"
    echo ""
}

# Check if main.parameters.json exists
if [ ! -f "main.parameters.json" ]; then
    create_parameters_file
fi

# Exit if in test mode
if [ "$TEST_MODE" = true ]; then
    echo "✅ Parameter file creation test completed successfully!"
    echo "📄 Created: main.parameters.json"
    echo "🔍 Contents:"
    cat main.parameters.json
    exit 0
fi

# Check if jq is installed for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "❌ jq is required for JSON parsing but not installed."
    echo "Please install jq:"
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    echo "  RHEL/CentOS: sudo yum install jq"
    exit 1
fi

# Variables
RESOURCE_GROUP_NAME="rg-d4sql-sims"
LOCATION=$(jq -r '.parameters.location.value' main.parameters.json)
DEPLOYMENT_NAME="sqlmi-deployment-$(date +%Y%m%d-%H%M%S)"

echo "🚀 Starting Azure SQL Managed Instance deployment..."
echo "📍 Region: $LOCATION"

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
if [ "$TEST_MODE" = true ]; then
    echo "✅ Test mode: Skipping actual deployment"
    echo "📋 Resources that would be created:"
    echo "   - Resource Group: $RESOURCE_GROUP_NAME"
    echo "   - SQL Managed Instance in $LOCATION"
    echo "   - Public IP: $PUBLIC_IP"
    echo ""
    echo "📝 Parameters that would be used:"
    cat main.parameters.json | jq
else
    echo "🏗️  Deploying Bicep template..."
    echo "⚠️  Note: SQL Managed Instance deployment can take 3-6 hours to complete"
    DEPLOYMENT_RESULT=$(az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "main.bicep" \
        --parameters "@main.parameters.json" clientPublicIP="$PUBLIC_IP" \
        --name "$DEPLOYMENT_NAME" \
        --verbose 2>&1)
    
    DEPLOYMENT_EXIT_CODE=$?

    if [ $DEPLOYMENT_EXIT_CODE -eq 0 ]; then
        echo "✅ Deployment completed successfully!"
        
        # Extract SQL MI FQDN from deployment outputs
        echo "🔍 Retrieving SQL Managed Instance details..."
        SQL_MI_FQDN=$(az deployment group show \
            --resource-group "$RESOURCE_GROUP_NAME" \
            --name "$DEPLOYMENT_NAME" \
            --query "properties.outputs.sqlManagedInstanceFqdn.value" -o tsv 2>/dev/null)
        
        if [ -n "$SQL_MI_FQDN" ]; then
            echo "📊 SQL Managed Instance FQDN: $SQL_MI_FQDN"
            
            # Run the sensitive data creation script
            echo ""
            echo "🎯 Now creating sensitive test data for Defender CSPM detection..."
            echo "📂 Switching to SecurityTests directory..."
            
            if [ -f "SecurityTests/create-sensitive-data.sh" ]; then
                cd SecurityTests
                chmod +x create-sensitive-data.sh
                
                # Extract password from parameters file
                SQL_ADMIN_PASSWORD=$(jq -r '.parameters.sqlAdminPassword.value' ../main.parameters.json)
                
                echo "🚀 Running create-sensitive-data.sh..."
                ./create-sensitive-data.sh --host "$SQL_MI_FQDN" --password "$SQL_ADMIN_PASSWORD"
                
                cd ..
                
                echo ""
                echo "🎉 COMPLETE DEPLOYMENT SUCCESS!"
                echo "================================="
                echo "✅ Infrastructure deployed"
                echo "✅ Sensitive test data created"
                echo "✅ Ready for Defender testing"
                echo ""
                echo "🧪 Next steps:"
                echo "   cd SecurityTests"
                echo "   ./test-defender-sql-alerts.sh --host $SQL_MI_FQDN --username d4sqlsim --password '$SQL_ADMIN_PASSWORD' --batch"
                echo "   # Or run interactively: ./test-defender-sql-alerts.sh --host $SQL_MI_FQDN --menu"
            else
                echo "⚠️  Warning: SecurityTests/create-sensitive-data.sh not found"
                echo "📋 Manual step: Create sensitive data using SecurityTests scripts"
            fi
        else
            echo "⚠️  Warning: Could not retrieve SQL MI FQDN from deployment outputs"
            echo "📋 Manual step: Use auto-discovery: cd SecurityTests && ./test-defender-sql-alerts.sh --auto-discover --menu"
        fi
        
        # Show monitoring information for successful deployments
        echo ""
        echo "📊 Monitor the deployment in the Azure Portal:"
        echo "   https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/overview"
        
    else
        echo "❌ Deployment failed!"
        echo "📋 Error details:"
        echo "$DEPLOYMENT_RESULT"
        
        echo ""
        echo "📊 You can check the deployment in the Azure Portal:"
        echo "   https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/overview"
        
        echo ""
        echo "🔍 To check deployment status:"
        echo "   az deployment group show --resource-group $RESOURCE_GROUP_NAME --name $DEPLOYMENT_NAME --query properties.provisioningState"
        
        exit 1
    fi
fi

echo ""
echo "📝 Deployment details:"
echo "   Resource Group: $RESOURCE_GROUP_NAME"
echo "   Deployment Name: $DEPLOYMENT_NAME"
echo "   Location: $LOCATION"
echo "   SQL Admin Username: d4sqlsim"
echo "   Your Public IP: $PUBLIC_IP"
