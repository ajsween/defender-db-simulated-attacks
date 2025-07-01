# Security Testing Scripts

This folder contains scripts designed to test the security posture of the deployed SQL Managed Instance and validate that Defender for Database is properly configured and functioning.

## Quick Start

**If you used the main `deploy.sh` script**, sensitive test data has already been created automatically! You can jump straight to security testing:

```bash
cd SecurityTests

# Interactive mode (recommended) - menu-driven testing
./test-defender-sql-alerts.sh

# Quick command line test
./test-defender-sql-alerts.sh --host [YOUR-SQL-MI-FQDN] --test password-brute

# Comprehensive batch testing (all tests)
./test-defender-sql-alerts.sh --host [YOUR-SQL-MI-FQDN] --username d4sqlsim --password 'YourPassword' --batch
```

**If you deployed manually**, follow the complete workflow below.

## Scripts Overview

### 1. `test-defender-sql-alerts.sh` ⭐ **COMPREHENSIVE TESTING SUITE**
**Purpose**: Unified, menu-based security testing suite that combines all brute force, SQL injection, and Defender alert testing in one comprehensive tool.

**Key Features**:
- **Interactive Menu Mode**: User-friendly menu system for guided testing
- **Command Line Mode**: Direct test execution for automation and scripting
- **Batch Mode**: Run all tests in sequence with comprehensive reporting
- **Integrated Brute Force Testing**: Password attacks, username enumeration, and comprehensive brute force
- **Advanced Security Testing**: SQL injection, harmful application detection, suspicious queries
- **Comprehensive Reporting**: HTML and JSON reports with detailed analysis
- **Real-time Monitoring**: Progress tracking and status updates

**Testing Categories**:
- **Password Brute Force**: Tests password attacks on known usernames (3 wordlist sizes)
- **Username Enumeration**: Tests discovery of valid usernames (3 wordlist sizes)  
- **Comprehensive Brute Force**: Combined password and username attacks
- **SQL Injection Testing**: Vulnerability detection and attack simulation
- **Harmful Application Detection**: Malicious tool connection simulation
- **Suspicious Query Patterns**: Anomalous SQL activity testing
- **Database Enumeration**: Information gathering and reconnaissance
- **Shell Command Execution**: Command execution attempt testing

**Usage Modes**:
```bash
# Interactive mode (recommended for first-time users)
./test-defender-sql-alerts.sh

# Interactive mode with pre-configured target
./test-defender-sql-alerts.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --menu

# Command line - specific test
./test-defender-sql-alerts.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --test password-brute

# Command line - comprehensive testing
./test-defender-sql-alerts.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --username d4sqlsim --password 'YourPassword' --batch

# Verbose output for debugging
./test-defender-sql-alerts.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --test sql-injection --verbose
```

**Expected Alerts**:
- **SQL.MI_BruteForce**: Multiple failed login attempts detected
- **SQL.MI_PrincipalAnomaly**: Unusual user access patterns
- **SQL.MI_VulnerabilityToSqlInjection**: Potential SQL injection vulnerability
- **SQL.MI_PotentialSqlInjection**: Active SQL injection attempts
- **SQL.MI_HarmfulApplication**: Connection from potentially harmful application
- **SQL.MI_SuspiciousIpAnomaly**: Access from suspicious IP address
- **Various Anomaly Alerts**: Enumeration, reconnaissance, and suspicious activity detection

### 2. `create-sensitive-data.sh` ⭐ **AUTOMATED**
**Purpose**: Comprehensive testing script that covers ALL applicable Defender for SQL alerts for Azure SQL Managed Instance.

**Features**:
- Tests all documented Defender for SQL alert types
- SQL injection vulnerability and attack simulation
- Brute force attack detection testing
- Harmful application detection
- Suspicious query pattern testing
- Database enumeration and reconnaissance
- Shell command execution attempts (limited on SQL MI)
- Comprehensive reporting with expected alerts mapping

**Coverage**:
- SQL.MI_BruteForce alerts
- SQL.MI_VulnerabilityToSqlInjection alerts  
- SQL.MI_PotentialSqlInjection alerts
- SQL.MI_HarmfulApplication alerts
- SQL.MI_SuspiciousIpAnomaly alerts
- SQL.MI_PrincipalAnomaly alerts
- SQL.MI_DomainAnomaly alerts
- SQL.MI_GeoAnomaly alerts
- SQL.MI_DataCenterAnomaly alerts
- SQL.MI_ShellExternalSourceAnomaly alerts

**Usage**:
```bash
# Run all tests (recommended)
./test-defender-sql-alerts.sh --host sqlmi-d4sqlsim-abc123.database.windows.net

# Run with authentication for advanced tests
./test-defender-sql-alerts.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --username d4sqlsim --password 'YourPassword'

# Run specific test category
./test-defender-sql-alerts.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --test sql-injection

# Available test categories: brute-force, sql-injection, harmful-application, suspicious-queries, enumeration, shell-commands, all
```

### 3. `get-sql-mi-fqdn.sh`
**Purpose**: Creates realistic fake sensitive data in SQL Managed Instance to test Defender CSPM's data discovery and classification capabilities.

**Features**:
- Creates normalized database schema (Third Normal Form)
- Generates 95 employee records with realistic fake sensitive data
- Multiple sensitive data types for comprehensive testing
- Follows realistic data patterns for accurate detection
- Comprehensive monitoring and validation guidance

**Sensitive Data Types Created**:
- **Social Security Numbers**: XXX-XX-XXXX format (95 records)
- **Credit Card Numbers**: Visa, MasterCard, Amex, Discover, JCB, Diners Club
- **Driver's License Numbers**: Various state-specific formats
- **Email Addresses**: Personal email addresses
- **Phone Numbers**: US phone number format
- **Physical Addresses**: Complete address information

**Database Schema**:
- `Employees` table (95 records with SSNs, emails, salaries)
- `UserProfiles` table (95 records with driver's licenses, addresses) 
- `EmployeeCreditCards` table (190-285 records with credit card data)
- Reference tables (States, CreditCardTypes, Departments)
- Normalized design following Third Normal Form

**Usage**:
```bash
# Create sensitive data with default username
./create-sensitive-data.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --password 'D4SqlSim2025!@#ComplexP@ssw0rd'

# With custom username
./create-sensitive-data.sh --host sqlmi-d4sqlsim-abc123.database.windows.net --username myuser --password 'MyPassword'
```

**Expected Defender CSPM Alerts**:
- Data Discovery & Classification recommendations
- SQL Information Protection policy triggers
- Sensitive data exposure findings
- Microsoft Purview catalog integration (if enabled)

### 4. `get-sql-mi-fqdn.sh`
**Purpose**: Helper script to retrieve the SQL Managed Instance FQDN from Azure and provide ready-to-use test commands.

**Features**:
- Automatically queries Azure for SQL MI details
- Provides formatted test commands
- Validates deployment completion

**Usage**:
```bash
./get-sql-mi-fqdn.sh
```

## Quick Start - Comprehensive Testing

For the most thorough security validation:

### 1. Get SQL MI Details
```bash
./get-sql-mi-fqdn.sh
```

### 2. Run Comprehensive Tests
```bash
# Basic comprehensive test (no authentication required)
./test-defender-sql-alerts.sh --host [YOUR-SQL-MI-FQDN]

# Advanced test with authentication (recommended for full coverage)
./test-defender-sql-alerts.sh --host [YOUR-SQL-MI-FQDN] --username d4sqlsim --password 'D4SqlSim2025!@#ComplexP@ssw0rd'
```

### 3. Monitor Data Classification
```bash
# Create realistic fake sensitive data for CSPM testing
./create-sensitive-data.sh --host [YOUR-SQL-MI-FQDN] --password 'D4SqlSim2025!@#ComplexP@ssw0rd'
```

### 4. Validate Detection
- Azure Portal > SQL MI > Data Discovery & Classification
- Defender for Cloud > Recommendations > Data & Storage
- Microsoft Purview catalog (if enabled)

## Complete Testing Workflow

For comprehensive security validation of both attack detection and data protection:

### Phase 1: Infrastructure & Attack Detection
```bash
# 1. Get SQL MI connection details
./get-sql-mi-fqdn.sh

# 2. Test attack detection capabilities
./test-defender-sql-alerts.sh --host [YOUR-SQL-MI-FQDN] --username d4sqlsim --password 'D4SqlSim2025!@#ComplexP@ssw0rd'
```

### Phase 2: Data Protection & Classification
```bash
# 3. Create sensitive data for CSPM testing  
./create-sensitive-data.sh --host [YOUR-SQL-MI-FQDN] --password 'D4SqlSim2025!@#ComplexP@ssw0rd'
```

### Phase 3: Validation & Monitoring
- **Attack Detection**: Monitor Azure Security Center (5-15 minutes)
- **Data Classification**: Check Data Discovery & Classification (30 minutes - 24 hours)
- **Compliance**: Review Defender for Cloud recommendations
- **Reports**: Check generated reports in `results/` folder

## Testing Methodology

### 1. Pre-Test Setup
1. Ensure SQL Managed Instance is deployed and accessible
2. Verify Defender for Database is enabled
3. Confirm Log Analytics workspace is receiving logs
4. Set up monitoring for Azure Security Center alerts

### 2. Test Execution
1. **Service Enumeration**: Attempts to gather SQL Server information
2. **Brute Force Attack**: Systematic password guessing using wordlists
3. **Detection Validation**: Monitor for security alerts and responses

### 3. Expected Results
Defender for Database should detect and alert on:
- ✅ Brute force login attempts
- ✅ Suspicious authentication patterns  
- ✅ Multiple failed login attempts
- ✅ Service enumeration attempts
- ✅ Anomalous connection patterns

### 4. Post-Test Analysis
1. Review Azure Security Center alerts
2. Check Log Analytics workspace for security events
3. Validate SQL MI audit logs
4. Assess Defender for Database recommendations
5. Review generated test reports

## Output Files

The scripts create organized output in the following structure:
```
SecurityTests/
├── logs/           # Detailed execution logs
├── results/        # Test results and enumeration data
├── wordlists/      # Generated username and password lists
└── reports/        # Markdown test reports
```

## Prerequisites

### Dependencies
- **Nmap**: Required for NSE script execution
  - macOS: `brew install nmap`
  - Ubuntu/Debian: `sudo apt-get install nmap`
- **Azure CLI**: Required for FQDN helper script
- **Bash**: Scripts require Bash shell environment

### Permissions
- Authorized access to test the target SQL Managed Instance
- Azure subscription access for retrieving SQL MI details
- Network connectivity to the SQL MI from your testing location

## Security Considerations

⚠️ **Authorization Required**: Only run these tests against systems you own or have explicit permission to test.

⚠️ **Detection Purpose**: These tests are designed to trigger security alerts - this is expected behavior.

⚠️ **Rate Limiting**: Use appropriate delays to avoid overwhelming the target system.

⚠️ **Monitoring**: Always monitor Azure Security Center during testing to validate alert generation.

## Troubleshooting

### Common Issues
1. **Nmap NSE Scripts Missing**: Ensure Nmap is properly installed with NSE scripts
2. **Network Connectivity**: Verify firewall rules allow connections from your IP
3. **Azure CLI Authentication**: Ensure you're logged in with appropriate permissions
4. **SQL MI Not Ready**: Deployment can take 3-6 hours - verify completion first

### Debug Commands
```bash
# Test network connectivity
nmap -p 1433 sqlmi-d4sqlsim-abc123.database.windows.net

# Verify NSE scripts
nmap --script-help ms-sql-brute

# Check Azure CLI authentication
az account show
```

## Integration with CI/CD

These scripts can be integrated into automated security testing pipelines:

```yaml
# Example Azure DevOps pipeline step
- task: Bash@3
  displayName: 'Run SQL MI Security Tests'
  inputs:
    targetType: 'filePath'
    filePath: 'SecurityTests/test-defender-sql-alerts.sh'
    arguments: '--host $(SQL_MI_FQDN) --username $(SQL_USERNAME) --password $(SQL_PASSWORD) --batch'
```

## Contributing

When adding new security tests:
1. Follow the existing script structure and conventions
2. Include comprehensive error handling and logging
3. Update this README with new test descriptions
4. Ensure tests are designed to trigger appropriate security alerts

---

**Note**: These tests are specifically designed for validating Defender for Database protection. The goal is to generate security alerts that demonstrate proper detection capabilities.
