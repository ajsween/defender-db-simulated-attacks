# Azure SQL Managed Instance Deployment

This repository contains Bicep templates to deploy an Azure SQL Managed Instance with associated resources for database security simulations.

## Resources Created

1. **Resource Group**: `rg-d4sql-sims`
2. **Azure SQL Managed Instance**: with unique name suffix
3. **Log Analytics Workspace**: `law-d4sqlsim`
4. **Virtual Network**: `vnet-d4sqlsim` with dedicated subnet
5. **Network Security Group**: configured for SQL MI requirements
6. **Route Table**: for proper network routing
7. **Diagnostic Settings**: sending all SQL MI logs to Log Analytics

## Security Configuration

- **Authentication**: SQL Server authentication with username `d4sqlsim`
- **Network Access**: Restricted to your current public IP address (dynamically retrieved during deployment)
- **Firewall**: Configured to allow only your IP on port 1433
- **TLS**: Minimum TLS version 1.2
- **Public Endpoint**: Enabled for external connectivity

## Files

- `main.bicep`: Main Bicep template
- `main.parameters.json`: Parameter file with default values
- `deploy.sh`: Deployment script
- `audit-security.sh`: Security audit script to verify no hardcoded sensitive data
- `SecurityTests/`: Security testing scripts for validating Defender for Database
- `README.md`: This documentation

## Environment Variables

This project follows security best practices by avoiding hardcoded sensitive data:

- **Subscription ID**: Automatically detected from Azure CLI or set via `AZURE_SUBSCRIPTION_ID`
- **Passwords**: Stored only in `main.parameters.json` (excluded from version control in public repos)
- **Public IP**: Dynamically retrieved during deployment

### Optional Environment Variables

```bash
export AZURE_SUBSCRIPTION_ID="your-subscription-id"  # If not using default Azure CLI subscription
```

## Prerequisites

1. Azure CLI installed and configured
2. Appropriate permissions in the target subscription
3. Bicep CLI (automatically installed with Azure CLI)

## Deployment

### Option 1: Using the Deployment Script (Recommended)

The deployment script provides a complete end-to-end deployment with interactive setup:

```bash
./deploy.sh
```

**Interactive Setup (if main.parameters.json doesn't exist):**
1. 🔐 **Password Creation**
   - Prompts for SQL admin password with complexity requirements
   - Validates password meets Azure SQL MI security requirements
   - Requirements: 12+ chars, upper/lower case, digits, special chars
   - Excludes: quotes, backslashes, 'admin', 'sql'

2. 🌍 **Region Selection**
   - Choose from 9 US Azure regions
   - Options include East US, West US 2, Central US, etc.

**What it does:**
1. ✅ Creates `main.parameters.json` interactively if missing
2. ✅ Deploys all Azure infrastructure (SQL MI, VNet, NSG, etc.)
3. ✅ Automatically detects your public IP for firewall rules
4. ✅ Validates deployment success
5. ✅ **Automatically creates sensitive test data** if deployment succeeds
6. ✅ Provides next steps for security testing

**Expected output on success:**
- Infrastructure deployed
- Sensitive test data created in SQL MI
- Ready for Defender for SQL testing

**Duration:** 3-6 hours (SQL MI provisioning time)

**Test Mode:**
```bash
# Test parameter creation without deploying
./deploy.sh --test-params
```

### Option 2: Manual Deployment

1. **Login to Azure**:
   ```bash
   az login
   # The deployment script will automatically use your current subscription
   # Or set a specific one:
   # az account set --subscription "YOUR_SUBSCRIPTION_ID"
   ```

2. **Create Resource Group**:
   ```bash
   az group create --name "rg-d4sql-sims" --location "East US 2"
   ```

3. **Deploy Template**:
   ```bash
   # Get your current public IP first
   PUBLIC_IP=$(curl -s ifconfig.me)
   
   az deployment group create \
     --resource-group "rg-d4sql-sims" \
     --template-file "main.bicep" \
     --parameters "@main.parameters.json" clientPublicIP="$PUBLIC_IP"
   ```

## Connection Details

After deployment completes:

- **Server**: Use the FQDN from the deployment output
- **Username**: `d4sqlsim`
- **Password**: `D4SqlSim2025!@#ComplexP@ssw0rd`
- **Port**: `1433`

## Important Notes

⚠️ **Deployment Time**: SQL Managed Instance deployment typically takes 3-6 hours to complete.

⚠️ **Cost**: Even with cost optimizations (2 vCores, BasePrice licensing, local backup redundancy), SQL Managed Instance costs ~$185-225/month. Monitor your usage and consider alternatives if budget is a concern.

⚠️ **Dynamic IP**: The deployment script automatically detects and uses your current public IP address. The firewall rules will be configured for the IP address you have when running the deployment.

## Dynamic IP Configuration

The deployment automatically detects and uses your current public IP address:

- **Automatic Detection**: Uses `curl -s ifconfig.me` with fallback to `ipinfo.io/ip`
- **Error Handling**: Deployment fails if IP cannot be detected
- **Flexibility**: Works from any location without code changes
- **Security**: Ensures only your current IP can access the SQL Managed Instance

If you need to update the IP address after deployment (e.g., if you change networks), you can either:
1. Redeploy the template (recommended)
2. Manually update the Network Security Group rules in the Azure Portal

## Monitoring

- All diagnostic logs are automatically sent to the Log Analytics Workspace
- Available log categories include:
  - Resource usage stats
  - Database wait statistics
  - SQL insights
  - Query store runtime statistics
  - Query store wait statistics
  - Errors
  - Database wait statistics

## Security Best Practices

This project follows security best practices:

### Sensitive Data Management
- **Passwords**: Only stored in `main.parameters.json` with secure parameter annotation
- **Subscription IDs**: Automatically detected or sourced from environment variables
- **No Hardcoded Secrets**: All scripts use parameters or environment variables
- **Version Control**: The `.gitignore` excludes sensitive files but includes `main.parameters.json` for template completeness

### Parameter File Security
- `main.parameters.json` contains sample/default values for template completeness
- **For production**: Create a separate private parameter file or use Azure Key Vault
- **For public repos**: Add `main.parameters.json` to `.gitignore` to prevent exposing actual credentials
- **Current setup**: Included for development/testing with sample values

### Network Security
- Public endpoint enabled for external connectivity
- NSG rules restrict access to your public IP only
- TLS 1.2 minimum required
- Network isolation through dedicated subnet

## Cost Optimization

This template is configured for the most cost-effective SQL Managed Instance deployment suitable for testing and simulations:

### Configuration Choices

- **Compute**: 2 vCores (minimum allowed) instead of 4+ vCores
  - Reduces compute costs by ~50% compared to default configurations
  - Sufficient for testing, development, and security simulations
  
- **License Type**: `BasePrice` instead of `LicenseIncluded`
  - Allows use of Azure Hybrid Benefit if you have existing SQL Server licenses
  - Can provide significant savings (up to 55%) if you have qualifying licenses
  - Even without existing licenses, often still more cost-effective than LicenseIncluded
  
- **Storage**: 32GB (minimum required)
  - Smallest storage allocation available
  - Can be increased later if needed
  
- **Backup Redundancy**: Local instead of Geo-redundant
  - Reduces backup storage costs by ~30-40%
  - Provides protection within the same Azure region
  - Suitable for non-production workloads

### Estimated Monthly Costs

Based on East US 2 pricing (as of 2025):
- **Compute**: ~$180-220/month (2 vCores, BasePrice licensing)
- **Storage**: ~$4/month (32GB)
- **Backup**: ~$1-2/month (local redundancy)
- **Total**: ~$185-225/month

> **Note**: Actual costs may vary based on region, usage patterns, and current Azure pricing. Always check the Azure Pricing Calculator for current estimates.

### Further Cost Reduction Options

If costs are still too high for your use case, consider these alternatives:

1. **Azure SQL Database**: Much cheaper than Managed Instance
2. **SQL Server on VM**: More control over sizing and costs
3. **Development/Test Pricing**: Special pricing if you have Dev/Test subscriptions

### Monitoring Costs

- Use Azure Cost Management to monitor spending
- Set up billing alerts to avoid unexpected charges
- Consider using Azure reservations for long-term deployments (1-3 year commitments)

## Cleanup

To remove all resources:

```bash
az group delete --name "rg-d4sql-sims" --yes --no-wait
```

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**: Ensure you have Contributor role on the subscription
2. **IP Detection Failure**: If the script cannot detect your public IP, check your internet connection
3. **IP Address Changes**: If your IP changes after deployment, you'll need to update the NSG rules manually or redeploy
4. **Deployment Timeout**: SQL MI deployments can take several hours - this is normal

### Checking Deployment Status

```bash
az deployment group list --resource-group "rg-d4sql-sims" --query "[0].{Name:name, State:properties.provisioningState, Timestamp:properties.timestamp}"
```

## Support

For issues with the deployment, check:
1. Azure Activity Log in the portal
2. Deployment details in the resource group
3. Network connectivity from your IP address

## Security Testing

After deployment, you can validate Defender for Database protection using the included security testing scripts:

### Quick Start
```bash
# Get your SQL MI FQDN
cd SecurityTests
./get-sql-mi-fqdn.sh

# Run basic brute force test
./test-brute-force.sh --host [YOUR-SQL-MI-FQDN]
```

### Test Options
- **Basic Test**: Small wordlist, standard settings
- **Comprehensive Test**: Medium/large wordlists with custom parameters
- **Stealth Test**: Slower rate with delays to simulate realistic attacks

### Expected Alerts
The tests should trigger Defender for Database alerts in Azure Security Center:
- Brute force login attempts
- Suspicious authentication patterns
- Service enumeration activities
- Multiple failed login attempts

See `SecurityTests/README.md` for detailed testing instructions and methodology.

### Security Audit

Run the included security audit script to verify no sensitive data is hardcoded:

```bash
./audit-security.sh
```

This script checks for:
- Hardcoded subscription IDs outside parameter files
- Hardcoded connection strings in code
- Proper .gitignore configuration
- Hardcoded passwords in scripts
