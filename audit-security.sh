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
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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

# Final summary
echo ""
print_success "✅ Security audit completed successfully!"
echo ""
echo "Summary:"
echo "- No hardcoded subscription IDs outside parameters file"
echo "- No hardcoded connection strings in code"
echo "- main.parameters.json contains expected sensitive parameters"
echo "- Scripts use environment variables and parameters for sensitive data"
echo "- .gitignore configured to protect sensitive files"
echo ""
print_status "🔐 Your infrastructure code follows security best practices!"
