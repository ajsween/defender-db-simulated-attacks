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
- **Firewall**: Configured to allow only your IP on port 3342 (public endpoint)
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

## Development Environment Setup

This project includes a `shell.nix` file for easy setup of the development environment using the Nix package manager. This provides reproducible environments across different platforms.

### Option 1: Using Nix (Recommended for Development)

The `shell.nix` file automatically installs all required dependencies:
- `jq` - JSON processor for Azure CLI output parsing
- `nmap` - Network security scanner for security testing
- `sqlcmd` - Microsoft SQL Server command-line tools

#### Installing Nix

**Linux (including WSL):**
```bash
# Install Nix using the official installer (multi-user installation)
curl -L https://nixos.org/nix/install | sh -s -- --daemon

# Source the profile
. /etc/profile

# Or single-user installation (if you prefer)
curl -L https://nixos.org/nix/install | sh
. ~/.nix-profile/etc/profile.d/nix.sh
```

**macOS:**
```bash
# Install Nix using the official installer
curl -L https://nixos.org/nix/install | sh

# Source the profile
. ~/.nix-profile/etc/profile.d/nix.sh

# Or install via Homebrew (alternative)
# brew install nix
```

**Windows (WSL):**
```bash
# First, ensure you have WSL 2 installed
# Install Ubuntu or your preferred Linux distribution from Microsoft Store

# Then follow the Linux installation steps above
curl -L https://nixos.org/nix/install | sh -s -- --daemon
. /etc/profile
```

#### Using the Development Environment

Once Nix is installed, navigate to the project directory and enter the development shell:

```bash
# Enter the development environment with all dependencies
nix-shell

# You should see a message confirming the loaded tools:
# Development environment loaded with:
# - jq: JSON processor
# - nmap: Network security scanner  
# - sqlcmd: Microsoft SQL Server
```

The development shell will automatically have all required tools available. Exit the shell with `exit` when done.

#### Benefits of Using Nix

- **Reproducible Environments**: Identical tool versions across all platforms
- **No System Pollution**: Dependencies are isolated and don't affect your system
- **Easy Cleanup**: Simply exit the shell to return to your normal environment
- **Automatic Updates**: Dependencies are managed declaratively
- **Cross-Platform**: Works consistently on Linux, macOS, and Windows (WSL)

### Option 2: Manual Installation

If you prefer not to use Nix, install the dependencies manually:

**Linux (Ubuntu/Debian):**
```bash
# Update package list
sudo apt update

# Install dependencies
sudo apt install -y jq nmap

# Install SQL Server command-line tools
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/msprod.list
sudo apt update
sudo apt install -y mssql-tools unixodbc-dev

# Add to PATH
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc
```

**macOS:**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install dependencies
brew install jq nmap

# Install SQL Server command-line tools
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install mssql-tools
```

**Windows (PowerShell):**
```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install dependencies
choco install -y jq nmap

# Install SQL Server command-line tools
# Download and install from: https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility
```

### Verification

After installation (either method), verify the tools are available:

```bash
# Check tool versions
jq --version
nmap --version
sqlcmd -?

# Test Azure CLI integration
az --version
```

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

- **Server**: Use the public endpoint FQDN: `<mi-name>.public.<dns-zone>.database.windows.net`
- **Username**: `d4sqlsim`
- **Password**: `YourPassword`
- **Port**: `3342` (public endpoint port)

## Important Notes

⚠️ **Deployment Time**: SQL Managed Instance deployment typically takes 3-6 hours to complete.

⚠️ **Cost**: Even with cost optimizations (4 vCores, BasePrice licensing, local backup redundancy), SQL Managed Instance costs ~$350-400/month. Monitor your usage and consider alternatives if budget is a concern.

⚠️ **Dynamic IP**: The deployment script automatically detects and uses your current public IP address. The firewall rules will be configured for the IP address you have when running the deployment on **port 3342** (public endpoint).

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

## Cost Management & Optimization

This template is configured for reliable SQL Managed Instance deployment suitable for testing and security simulations. Here's the cost breakdown and optimization options:

### Configuration Choices

- **Compute**: 4 vCores (standard configuration) for reliable performance
  - Provides good balance between cost and performance
  - Sufficient for testing, development, and security simulations with multiple concurrent connections
  
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

Based on East US pricing (as of 2025):
- **Compute**: ~$350-400/month (4 vCores, BasePrice licensing)
- **Storage**: ~$4/month (32GB)
- **Backup**: ~$1-2/month (local redundancy)
- **Total**: ~$355-405/month

> **Note**: Actual costs may vary based on region, usage patterns, and current Azure pricing. Always check the Azure Pricing Calculator for current estimates.

### Further Cost Reduction Options

If costs are still too high for your use case, consider these alternatives:

1. **Reduce to 2 vCores**: Modify `main.bicep` to use 2 vCores instead of 4
   - Change `vCores: 4` to `vCores: 2` and `capacity: 4` to `capacity: 2`
   - Reduces costs to ~$180-220/month but may impact performance with concurrent connections

2. **Azure SQL Database**: Much cheaper than Managed Instance
   - Single database: ~$15-50/month for testing workloads
   - Elastic pools: ~$20-100/month for multiple databases

3. **SQL Server on VM**: More control over sizing and costs
   - B-series VMs: ~$30-100/month for development/testing
   - Can pause/stop when not in use

4. **Development/Test Pricing**: Special pricing if you have Dev/Test subscriptions
   - Up to 55% savings on compute costs
   - Available with Visual Studio subscriptions

### Monitoring Costs

- **Azure Cost Management**: Monitor spending and set up cost alerts
  - Set budget alerts at $300, $350, and $400 monthly thresholds
  - Review daily costs to catch unexpected spikes early

- **Billing Alerts**: Configure notifications for different spending levels
  - Warning at 80% of budget (~$280/month)
  - Critical at 100% of budget (~$350/month)

- **Cost Optimization Tips**:
  - **Stop during off-hours**: Use automation to pause/start SQL MI if supported
  - **Right-size storage**: Monitor storage usage and adjust as needed
  - **Azure Reservations**: 1-3 year commitments can save 20-60%
  - **Azure Hybrid Benefit**: Use existing SQL Server licenses for additional savings

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
cd SecurityTests

# Auto-discover and run interactive testing (recommended)
./test-defender-sql-alerts.sh --auto-discover --menu

# Or manually specify host (use public endpoint format and port 3342)
./test-defender-sql-alerts.sh --host your-sql-mi.public.dns-zone.database.windows.net --port 3342

# Quick command line test with auto-discovery
./test-defender-sql-alerts.sh --host [YOUR-SQL-MI-FQDN] --test password-brute

# Comprehensive testing (all tests) 
# Note: Use the public endpoint FQDN format: <mi-name>.public.<dns-zone>.database.windows.net
./test-defender-sql-alerts.sh --host [YOUR-SQL-MI-FQDN] --username d4sqlsim --password [YOUR-PASSWORD] --batch
```

### Test Options
- **Interactive Mode**: Menu-driven testing with guided configuration
- **Password Brute Force**: Tests password attacks on known usernames (3 wordlist sizes)
- **Username Enumeration**: Tests discovery of valid usernames (3 wordlist sizes)  
- **Comprehensive Brute Force**: Combined password and username attacks
- **SQL Injection Testing**: Vulnerability detection and attack simulation
- **Advanced Security Tests**: Harmful applications, suspicious queries, enumeration, shell commands
- **Batch Mode**: Run all tests automatically with comprehensive reporting
- **Stealth Mode**: Configurable delays and threading for realistic attack patterns

### Expected Alerts
The tests should trigger Defender for Database alerts in Azure Security Center:
- Brute force login attempts (both password and username attacks)
- Suspicious authentication patterns
- SQL injection attempts and vulnerabilities
- Harmful application detection
- Service enumeration activities
- Multiple failed login attempts
- Anomalous database access patterns

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
