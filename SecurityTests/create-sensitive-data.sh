#!/bin/bash

# SQL Managed Instance Sensitive Data Creation Script
# This script creates realistic fake sensitive data to test Defender CSPM capabilities

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="$SCRIPT_DIR/create-sensitive-data.sql"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PORT="3342"
DEFAULT_USERNAME="d4sqlsim"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script creates sensitive data tables in SQL Managed Instance to test 
Defender CSPM's sensitive data detection and classification capabilities.

OPTIONS:
    -h, --host HOSTNAME         SQL MI hostname or FQDN (required unless using --auto-discover)
    -p, --port PORT            SQL Server port (default: $DEFAULT_PORT - public endpoint)
    -u, --username USERNAME    SQL Server username (default: $DEFAULT_USERNAME)
    -w, --password PASSWORD    SQL Server password (required)
    -v, --verbose              Verbose output
    --auto-discover            Auto-discover SQL MI public endpoint from Azure (default RG: rg-d4sql-sims)
    --resource-group RG_NAME   Resource group for auto-discovery (default: rg-d4sql-sims)
    --help                     Show this help message

EXAMPLES:
    # Auto-discover SQL MI public endpoint and create sensitive data
    $0 --auto-discover --password 'YourPassword'

    # Auto-discover from custom resource group
    $0 --auto-discover --resource-group my-rg --password 'YourPassword'

    # Manual host specification (use public endpoint format)
    $0 --host sqlmi-name.public.dns-zone.database.windows.net --password 'YourPassword'

    # With custom username and port
    $0 --host sqlmi-name.public.dns-zone.database.windows.net --port 3342 --username myuser --password 'YourPassword'

WHAT THIS SCRIPT CREATES:
    - SensitiveDataTest database
    - Normalized tables (3NF) with realistic fake data:
      * Employees (95 records with SSNs, emails, phone numbers)
      * UserProfiles (driver's licenses, addresses)
      * EmployeeCreditCards (credit card numbers, CVVs, expiration dates)
      * Reference tables (States, CreditCardTypes, Departments)

DATA TYPES FOR DEFENDER CSPM TESTING:
    - Social Security Numbers (XXX-XX-XXXX format)
    - Credit Card Numbers (Visa, MasterCard, Amex, Discover, JCB, Diners)
    - Driver's License Numbers (various state formats)
    - Email addresses
    - Phone numbers
    - Physical addresses

EXPECTED DEFENDER CSPM ALERTS:
    - Data Discovery & Classification alerts
    - Sensitive data exposure recommendations
    - SQL Information Protection policies triggered
    - Data governance insights

NOTES:
    - All data is completely fake but follows realistic patterns
    - Tables are designed in Third Normal Form
    - Between 95-285 total records across all tables
    - Data designed to trigger Microsoft Purview/Defender CSPM detection

EOF
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v sqlcmd &> /dev/null; then
        print_error "sqlcmd is not installed. Please install SQL Server command-line tools."
        print_status "Download from: https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility"
        print_status "On macOS: brew install microsoft/mssql-release/mssql-tools"
        exit 1
    fi
    
    if [[ ! -f "$SQL_FILE" ]]; then
        print_error "SQL file not found: $SQL_FILE"
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

# Function to test connection
test_connection() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    
    print_status "Testing connection to SQL Managed Instance..."
    
    if timeout 30s sqlcmd -S "$host,$port" -U "$username" -P "$password" -Q "SELECT GETDATE() AS CurrentTime, @@VERSION AS Version;" > /dev/null 2>&1; then
        print_success "Connection test successful"
        return 0
    else
        print_error "Connection test failed"
        print_error "Please verify:"
        print_error "1. SQL MI is running and accessible"
        print_error "2. Firewall rules allow your IP"
        print_error "3. Username and password are correct"
        return 1
    fi
}

# Function to create sensitive data
create_sensitive_data() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local verbose="$5"
    
    print_status "Creating sensitive data tables and records..."
    print_warning "This will create a new database 'SensitiveDataTest' with realistic fake sensitive data"
    
    # Execute the SQL script
    local sqlcmd_options="-S $host,$port -U $username -P $password -i $SQL_FILE"
    
    if [[ "$verbose" == "true" ]]; then
        sqlcmd_options="$sqlcmd_options -v"
    fi
    
    print_status "Executing SQL script: $SQL_FILE"
    
    if eval "sqlcmd $sqlcmd_options"; then
        print_success "Sensitive data creation completed successfully"
        return 0
    else
        print_error "Failed to create sensitive data"
        return 1
    fi
}

# Function to verify data creation
verify_data_creation() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    
    print_status "Verifying data creation..."
    
    local verification_query="
    USE SensitiveDataTest;
    
    PRINT 'Table Record Counts:';
    SELECT 'Employees' AS TableName, COUNT(*) AS RecordCount FROM Employees
    UNION ALL
    SELECT 'UserProfiles' AS TableName, COUNT(*) AS RecordCount FROM UserProfiles
    UNION ALL
    SELECT 'EmployeeCreditCards' AS TableName, COUNT(*) AS RecordCount FROM EmployeeCreditCards;
    
    PRINT '';
    PRINT 'Sample Sensitive Data (for verification):';
    SELECT TOP 3 'SSN' AS DataType, SSN AS SampleData FROM Employees
    UNION ALL
    SELECT TOP 3 'Credit Card' AS DataType, CardNumber AS SampleData FROM EmployeeCreditCards
    UNION ALL
    SELECT TOP 3 'Driver License' AS DataType, DriversLicenseNumber AS SampleData FROM UserProfiles;
    "
    
    echo "$verification_query" | sqlcmd -S "$host,$port" -U "$username" -P "$password"
}

# Function to generate monitoring recommendations
generate_monitoring_guide() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local guide_file="$SCRIPT_DIR/results/defender_cspm_monitoring_${timestamp}.md"
    
    mkdir -p "$SCRIPT_DIR/results"
    
    cat > "$guide_file" << EOF
# Defender CSPM Sensitive Data Monitoring Guide

## Overview
This guide helps you monitor and validate Defender CSPM's detection of the sensitive data created in your SQL Managed Instance.

## Created Database and Tables
- **Database**: SensitiveDataTest
- **Tables Created**:
  - Employees (95 records with SSNs)
  - UserProfiles (95 records with driver's licenses)
  - EmployeeCreditCards (~190-285 records with credit card data)
  - Reference tables (States, CreditCardTypes, Departments)

## Sensitive Data Types Created

### 1. Social Security Numbers (SSNs)
- **Format**: XXX-XX-XXXX
- **Table**: Employees.SSN
- **Pattern**: Follows valid SSN area/group/serial number rules
- **Count**: 95 unique SSNs

### 2. Credit Card Numbers
- **Formats**: 
  - Visa: 4XXX-XXXX-XXXX-XXXX
  - MasterCard: 5XXX-XXXX-XXXX-XXXX
  - American Express: 3XXX-XXXXXX-XXXXX
  - Discover: 6011-XXXX-XXXX-XXXX
  - JCB: 35XX-XXXX-XXXX-XXXX
  - Diners Club: 30XX-XXXX-XXXX-XX
- **Table**: EmployeeCreditCards.CardNumber
- **Additional**: CVV codes and expiration dates included

### 3. Driver's License Numbers
- **Formats**: Various state-specific patterns
- **Table**: UserProfiles.DriversLicenseNumber
- **Patterns**: Letters + numbers in state-appropriate formats

### 4. Personal Information
- **Email Addresses**: firstname.lastname@company.com format
- **Phone Numbers**: (XXX) XXX-XXXX format
- **Physical Addresses**: Complete address information

## Expected Defender CSPM Detections

### 1. Data Discovery & Classification
Monitor for these alerts in Microsoft Defender for Cloud:
- **SQL Information Protection**: Data classification recommendations
- **Sensitive Data Discovery**: Automatic data type detection
- **Data Governance**: Insights into sensitive data exposure

### 2. Microsoft Purview Integration
If Purview is connected:
- **Data Map**: Sensitive data assets discovered
- **Data Catalog**: Classified sensitive data types
- **Data Loss Prevention**: Policy recommendations

### 3. Compliance & Governance
- **Data Residency**: Geographic data storage insights
- **Regulatory Compliance**: GDPR, CCPA, HIPAA relevant findings
- **Access Controls**: Recommendations for data protection

## Monitoring Locations

### 1. Microsoft Defender for Cloud
- Navigate to: **Defender for Cloud > Recommendations**
- Look for: **Data & Storage** category recommendations
- Expected alerts:
  - "Sensitive data in your SQL databases should be classified"
  - "SQL databases should have vulnerability findings resolved"
  - "Advanced data security should be enabled on SQL Managed Instance"

### 2. SQL Managed Instance - Data Discovery
- Azure Portal > SQL Managed Instance > Security > Data Discovery & Classification
- Should automatically discover and suggest classification for:
  - SSN columns
  - Credit card number columns
  - Driver's license columns
  - Email address columns

### 3. Microsoft Purview (if enabled)
- Purview Portal > Data Map
- Look for newly discovered assets from SQL MI
- Check Data Catalog for classified sensitive data

### 4. Log Analytics Workspace
Use these KQL queries to monitor:

\`\`\`kusto
// Data classification events
AzureDiagnostics
| where Category == "SQLSecurityAuditEvents"
| where action_name_s contains "DATA_CLASSIFICATION"
| project TimeGenerated, database_name_s, schema_name_s, object_name_s, statement_s

// Sensitive data access
AzureDiagnostics  
| where Category == "SQLSecurityAuditEvents"
| where statement_s contains "SSN" or statement_s contains "CardNumber" or statement_s contains "DriversLicense"
| project TimeGenerated, client_ip_s, server_principal_name_s, statement_s
\`\`\`

## Validation Steps

### 1. Immediate (0-30 minutes)
1. Check SQL MI Data Discovery & Classification in Azure Portal
2. Run manual data discovery scan if available
3. Verify database and tables exist via SQL query

### 2. Short Term (30 minutes - 2 hours)
1. Monitor Defender for Cloud recommendations
2. Check for new security findings
3. Review data classification suggestions

### 3. Medium Term (2-24 hours)
1. Full Microsoft Purview catalog sync (if enabled)
2. Complete Defender CSPM assessment cycle
3. Comprehensive compliance report generation

## Sample Validation Queries

Connect to SQL MI and run these queries to verify data:

\`\`\`sql
-- Check database exists
SELECT name FROM sys.databases WHERE name = 'SensitiveDataTest';

-- Verify sensitive data patterns
USE SensitiveDataTest;

-- SSN pattern check
SELECT COUNT(*) as SSN_Count FROM Employees 
WHERE SSN LIKE '[0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9][0-9]';

-- Credit card pattern check  
SELECT CardTypeName, COUNT(*) as Card_Count 
FROM EmployeeCreditCards cc
JOIN CreditCardTypes cct ON cc.CardTypeID = cct.CardTypeID
GROUP BY CardTypeName;

-- Driver license check
SELECT COUNT(*) as License_Count FROM UserProfiles 
WHERE DriversLicenseNumber IS NOT NULL;
\`\`\`

## Cleanup Instructions

To remove the test data:

\`\`\`sql
-- Connect to SQL MI and run:
DROP DATABASE IF EXISTS SensitiveDataTest;
\`\`\`

## Troubleshooting

### No Data Classification Detected
1. Ensure Defender for SQL is enabled
2. Verify SQL Information Protection policies are active
3. Manually trigger data discovery scan
4. Check service permissions

### No Defender Recommendations
1. Wait up to 24 hours for full scan cycle
2. Verify Defender for Cloud is properly configured
3. Check subscription and resource group coverage
4. Review Log Analytics workspace connectivity

---
**Generated**: $(date)  
**Purpose**: Defender CSPM Sensitive Data Detection Validation  
**Database**: SensitiveDataTest  
**Records**: ~95-285 across all tables
EOF

    print_success "Monitoring guide created: $guide_file"
}

# Function to auto-discover SQL Managed Instance public endpoint FQDN
auto_discover_sql_mi_public_endpoint() {
    local resource_group="${1:-rg-d4sql-sims}"
    
    print_status "Auto-discovering SQL Managed Instance public endpoint from resource group: $resource_group" >&2
    
    # Check if Azure CLI is available
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI (az) is not installed. Cannot auto-discover SQL MI." >&2
        print_status "Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" >&2
        return 1
    fi
    
    # Check if logged into Azure CLI
    if ! az account show &> /dev/null; then
        print_error "Not logged into Azure CLI. Please run: az login" >&2
        return 1
    fi
    
    # Get subscription ID from Azure CLI or environment variable
    local subscription_id=""
    if [[ -z "$AZURE_SUBSCRIPTION_ID" ]]; then
        subscription_id=$(az account show --query id -o tsv 2>/dev/null)
        if [[ -z "$subscription_id" ]]; then
            print_error "Could not determine subscription ID. Please set AZURE_SUBSCRIPTION_ID environment variable or ensure you're logged into Azure CLI." >&2
            return 1
        fi
    else
        subscription_id="$AZURE_SUBSCRIPTION_ID"
        az account set --subscription "$subscription_id" 2>/dev/null
    fi
    
    print_status "Using subscription: $subscription_id" >&2
    
    # Check if resource group exists
    if ! az group show --name "$resource_group" &> /dev/null; then
        print_error "Resource group '$resource_group' not found in subscription." >&2
        print_status "Available resource groups:" >&2
        az group list --query "[].name" -o tsv 2>/dev/null | head -10 >&2
        return 1
    fi
    
    # Get the SQL MI name and private FQDN
    local sql_mi_name
    local sql_mi_private_fqdn
    
    sql_mi_name=$(az sql mi list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null)
    sql_mi_private_fqdn=$(az sql mi list --resource-group "$resource_group" --query "[0].fullyQualifiedDomainName" -o tsv 2>/dev/null)
    
    if [[ -z "$sql_mi_private_fqdn" ]]; then
        print_error "No SQL Managed Instance found in resource group: $resource_group" >&2
        print_status "Make sure the deployment is complete and the SQL MI exists." >&2
        return 1
    fi
    
    print_status "Found SQL MI: $sql_mi_name" >&2
    print_status "Private FQDN: $sql_mi_private_fqdn" >&2
    
    # Convert private FQDN to public endpoint FQDN
    # Format: sqlmi-name.dns-zone.database.windows.net -> sqlmi-name.public.dns-zone.database.windows.net
    local sql_mi_public_fqdn
    if [[ "$sql_mi_private_fqdn" =~ ^([^.]+)\.([^.]+)\.database\.windows\.net$ ]]; then
        local mi_name="${BASH_REMATCH[1]}"
        local dns_zone="${BASH_REMATCH[2]}"
        sql_mi_public_fqdn="${mi_name}.public.${dns_zone}.database.windows.net"
    else
        print_error "Could not parse SQL MI FQDN format: $sql_mi_private_fqdn" >&2
        return 1
    fi
    
    print_success "SQL Managed Instance discovered:" >&2
    print_status "Name: $sql_mi_name" >&2
    print_status "Private FQDN: $sql_mi_private_fqdn" >&2
    print_status "Public FQDN: $sql_mi_public_fqdn" >&2
    print_status "Resource Group: $resource_group" >&2
    
    # Return the public FQDN
    echo "$sql_mi_public_fqdn"
    return 0
}

# Main function
main() {
    local host=""
    local port="$DEFAULT_PORT"
    local username="$DEFAULT_USERNAME"
    local password=""
    local verbose="false"
    local auto_discover="false"
    local resource_group="rg-d4sql-sims"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host)
                host="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -u|--username)
                username="$2"
                shift 2
                ;;
            -w|--password)
                password="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift
                ;;
            --auto-discover)
                auto_discover="true"
                shift
                ;;
            --resource-group)
                resource_group="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Handle auto-discovery
    if [[ "$auto_discover" == "true" ]]; then
        if [[ -n "$host" ]]; then
            print_warning "Both --auto-discover and --host specified. Using auto-discovery."
        fi
        
        print_status "Auto-discovering SQL MI public endpoint..."
        if host=$(auto_discover_sql_mi_public_endpoint "$resource_group"); then
            print_success "Auto-discovery successful: $host"
        else
            print_error "Auto-discovery failed. Please specify --host manually."
            exit 1
        fi
    fi
    
    # Validate required parameters
    if [[ -z "$host" ]]; then
        print_error "Host is required. Use --host to specify the SQL MI hostname or --auto-discover."
        show_usage
        exit 1
    fi
    
    if [[ -z "$password" ]]; then
        print_error "Password is required. Use --password to specify the SQL Server password."
        show_usage
        exit 1
    fi
    
    print_status "=== SQL Managed Instance Sensitive Data Creation ==="
    print_status "Target: $host:$port"
    print_status "Username: $username"
    print_warning "This script will create realistic fake sensitive data for Defender CSPM testing"
    print_warning "Data includes SSNs, credit cards, driver's licenses, and personal information"
    echo ""
    
    # Setup and execution
    check_dependencies
    
    if ! test_connection "$host" "$port" "$username" "$password"; then
        exit 1
    fi
    
    if ! create_sensitive_data "$host" "$port" "$username" "$password" "$verbose"; then
        exit 1
    fi
    
    verify_data_creation "$host" "$port" "$username" "$password"
    generate_monitoring_guide
    
    print_success "=== Sensitive data creation completed! ==="
    print_status "Database 'SensitiveDataTest' created with realistic fake sensitive data"
    print_status "Monitor Defender for Cloud for data classification recommendations"
    print_warning "Expected detection time: 30 minutes - 24 hours depending on scan cycles"
    
    echo ""
    print_status "Next steps:"
    echo "1. Check Azure Portal > SQL MI > Data Discovery & Classification"
    echo "2. Monitor Defender for Cloud > Recommendations > Data & Storage"
    echo "3. Review Microsoft Purview catalog (if enabled)"
    echo "4. Check the generated monitoring guide for detailed validation steps"
}

# Run main function with all arguments
main "$@"
