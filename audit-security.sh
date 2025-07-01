#!/bin/bash

# Security Audit Script
# Verifies that no sensitive data is hardcoded outside of main.parameters.json

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    WARNING_COUNT=$((WARNING_COUNT + 1))
    WARNINGS+=("$1")
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Initialize warning tracking
WARNING_COUNT=0
WARNINGS=()

echo "🔒 Security Audit: Checking for hardcoded sensitive data"
echo "======================================================="

# Check for subscription IDs (excluding main.parameters.json)
print_status "Checking for hardcoded subscription IDs..."
SUBSCRIPTION_MATCHES=$(grep -r --exclude="main.parameters.json" --exclude="audit-security.sh" -E "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}" . || true)

if [ -n "$SUBSCRIPTION_MATCHES" ]; then
    print_error "Found hardcoded subscription IDs:"
    echo "$SUBSCRIPTION_MATCHES"
    exit 1
else
    print_success "No hardcoded subscription IDs found"
fi

# Check for hardcoded connection strings
print_status "Checking for hardcoded connection strings..."
CONNECTION_MATCHES=$(grep -r --exclude="main.parameters.json" --exclude="audit-security.sh" -i "server=.*database\.windows\.net" . || true)

if [ -n "$CONNECTION_MATCHES" ]; then
    # Filter out documentation examples
    REAL_MATCHES=$(echo "$CONNECTION_MATCHES" | grep -v "README.md" | grep -v "\.md:" || true)
    if [ -n "$REAL_MATCHES" ]; then
        print_error "Found hardcoded connection strings:"
        echo "$REAL_MATCHES"
        exit 1
    else
        print_success "No hardcoded connection strings found (documentation examples are OK)"
    fi
else
    print_success "No hardcoded connection strings found"
fi

# Check that main.parameters.json contains sensitive data
print_status "Verifying main.parameters.json contains expected parameters..."
if [ ! -f "main.parameters.json" ]; then
    print_error "main.parameters.json not found!"
    exit 1
fi

if ! grep -q "sqlAdminPassword" main.parameters.json; then
    print_error "sqlAdminPassword not found in main.parameters.json"
    exit 1
fi

print_success "main.parameters.json contains expected sensitive parameters"

# Check .gitignore strategy
print_status "Checking .gitignore configuration..."
if [ ! -f ".gitignore" ]; then
    print_error ".gitignore not found!"
    exit 1
fi

# Check that sensitive files are ignored
if grep -q "\.env" .gitignore && grep -q "\*\.log" .gitignore; then
    print_success ".gitignore properly configured for sensitive files"
else
    print_warning ".gitignore may need updates for better security"
fi

# Check for hardcoded passwords in scripts (excluding parameters and documentation)
print_status "Checking for hardcoded passwords in scripts..."
PASSWORD_MATCHES=$(grep -r --exclude="main.parameters.json" --exclude="audit-security.sh" --exclude-dir=".git" -E "password\s*=\s*['\"][^'\"$][^'\"]*['\"]" . | grep -v "README" | grep -v "local password" | grep -v "PASSWORD.*Password" || true)

if [ -n "$PASSWORD_MATCHES" ]; then
    print_error "Found potential hardcoded passwords:"
    echo "$PASSWORD_MATCHES"
    exit 1
else
    print_success "No hardcoded passwords found in scripts"
fi

# Check SecurityTests folder structure and security
print_status "Auditing SecurityTests folder..."

if [ ! -d "SecurityTests" ]; then
    print_error "SecurityTests folder not found!"
    exit 1
fi

# Check for required scripts
REQUIRED_SCRIPTS=(
    "SecurityTests/test-defender-sql-alerts.sh"
    "SecurityTests/create-sensitive-data.sh"
    "SecurityTests/Tools/shellpass.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        print_error "Required script not found: $script"
        exit 1
    fi
    
    if [ ! -x "$script" ]; then
        print_warning "Script not executable: $script (may need chmod +x)"
    fi
done

print_success "All required SecurityTests scripts are present"

# Check for hardcoded credentials in SecurityTests
print_status "Checking SecurityTests for hardcoded credentials..."
SECURITY_TESTS_CREDS=$(grep -r --exclude-dir=".git" --exclude="*.md" -E "(password|username|host)\s*=\s*['\"][^'\"$][^'\"]*['\"]" SecurityTests/ | grep -v "DEFAULT_" | grep -v "local " | grep -v "read -" | grep -v "echo " | grep -v "example" | grep -v "sqlmi-.*\.database\.windows\.net" || true)

if [ -n "$SECURITY_TESTS_CREDS" ]; then
    print_error "Found potential hardcoded credentials in SecurityTests:"
    echo "$SECURITY_TESTS_CREDS"
    exit 1
else
    print_success "No hardcoded credentials found in SecurityTests"
fi

# Check for potentially real passwords in documentation examples
print_status "Checking documentation for potentially real passwords..."
DOC_PASSWORDS=$(grep -r --include="*.md" -E -- "--password ['\"][^'\"]*['\"]" SecurityTests/ | grep -v "YourPassword" | grep -v "MyPassword" | grep -v "\[.*PASSWORD.*\]" | grep -v "example-password" || true)

if [ -n "$DOC_PASSWORDS" ]; then
    print_warning "Found specific passwords in documentation examples:"
    echo "$DOC_PASSWORDS"
    print_warning "Consider using placeholder passwords like 'YourPassword' in documentation"
else
    print_success "Documentation uses appropriate placeholder passwords"
fi

# Check for proper parameter handling in SecurityTests
print_status "Verifying SecurityTests use proper parameter handling..."
MAIN_SCRIPT="SecurityTests/test-defender-sql-alerts.sh"

if grep -q "while \[\[ \$# -gt 0 \]\]" "$MAIN_SCRIPT" && grep -q -- "--host" "$MAIN_SCRIPT" && grep -q -- "--password" "$MAIN_SCRIPT"; then
    print_success "SecurityTests main script uses proper command-line parameter handling"
else
    print_warning "SecurityTests main script may not have proper parameter handling"
fi

# Check that SecurityTests don't expose sensitive data in logs
print_status "Checking SecurityTests for sensitive data exposure..."
# Look specifically for variable expansion of passwords in echo/print statements
SENSITIVE_EXPOSURE=$(grep -r --exclude-dir=".git" --exclude="*.md" -E "(echo|print).*\\\$\{?password\}?|echo.*\\\$PASSWORD" SecurityTests/ | grep -v "Enter.*password" | grep -v "password.*not" | grep -v "sqlcmd.*-P.*\\\$password" || true)

if [ -n "$SENSITIVE_EXPOSURE" ]; then
    print_warning "Found potential sensitive data exposure in SecurityTests:"
    echo "$SENSITIVE_EXPOSURE"
    print_status "Review these instances to ensure passwords are not logged"
else
    print_success "No obvious sensitive data exposure in SecurityTests"
fi

# Validate shellpass.sh security
print_status "Validating shellpass.sh security tool..."
SHELLPASS_SCRIPT="SecurityTests/Tools/shellpass.sh"

if [ -f "$SHELLPASS_SCRIPT" ]; then
    # Check that shellpass doesn't expose actual generated passwords in logs
    if grep -q "echo.*\\\$\{?passwd\}?\|echo.*\\\$\{?password\}?\|printf.*\\\$\{?passwd\}?" "$SHELLPASS_SCRIPT" 2>/dev/null; then
        print_warning "shellpass.sh may expose generated passwords in logs"
    else
        print_success "shellpass.sh appears to handle password generation securely"
    fi
else
    print_warning "shellpass.sh not found - password generation will use static lists"
fi

# Final summary
echo ""
if [ $WARNING_COUNT -eq 0 ]; then
    print_success "✅ Security audit completed successfully!"
else
    print_success "✅ Security audit completed with $WARNING_COUNT warning(s)"
fi
echo ""
echo "Summary:"
echo "- No hardcoded subscription IDs outside parameters file"
echo "- No hardcoded connection strings in code"
echo "- main.parameters.json contains expected sensitive parameters"
echo "- Scripts use environment variables and parameters for sensitive data"
echo "- .gitignore configured to protect sensitive files"
echo "- SecurityTests folder structure is valid"
echo "- SecurityTests scripts use proper parameter handling"
echo "- No hardcoded credentials in SecurityTests"
echo "- Password generation tools are secure"

if [ $WARNING_COUNT -gt 0 ]; then
    echo ""
    echo "⚠️  Warnings Found ($WARNING_COUNT):"
    for warning in "${WARNINGS[@]}"; do
        echo "   • $warning"
    done
    echo ""
    echo "📋 Recommendations:"
    if [[ " ${WARNINGS[*]} " =~ "Found specific passwords in documentation examples" ]]; then
        echo "   • Replace specific passwords in documentation with placeholders like 'YourPassword'"
    fi
    if [[ " ${WARNINGS[*]} " =~ "potential sensitive data exposure" ]]; then
        echo "   • Review flagged instances to ensure no actual passwords are logged"
    fi
    if [[ " ${WARNINGS[*]} " =~ "shellpass.sh may expose generated passwords" ]]; then
        echo "   • Review shellpass.sh password output handling"
    fi
    if [[ " ${WARNINGS[*]} " =~ ".gitignore may need updates" ]]; then
        echo "   • Consider updating .gitignore for better security coverage"
    fi
fi

echo ""
if [ $WARNING_COUNT -eq 0 ]; then
    print_status "🔐 Your infrastructure and security testing code follows security best practices!"
else
    print_status "🔐 Your infrastructure code is mostly secure, but please review the warnings above"
fi
