#!/bin/bash
# Test script for running GitHub Actions locally with Act

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Act is installed
check_act_installed() {
    if ! command -v act &> /dev/null; then
        log_error "Act is not installed. Please install it first:"
        echo "  macOS: brew install act"
        echo "  Linux: curl -s https://api.github.com/repos/nektos/act/releases/latest | grep 'browser_download_url.*linux_amd64.tar.gz' | cut -d '\"' -f 4 | xargs curl -L | tar xz -C /usr/local/bin act"
        exit 1
    fi
    log_success "Act is installed: $(act --version)"
}

# Check if configuration files exist
check_config_files() {
    if [[ ! -f ".env.local" ]]; then
        log_warning ".env.local not found. Creating from example..."
        cp .env.local.example .env.local
        log_info "Please edit .env.local with your values"
    fi
    
    if [[ ! -f ".secrets.local" ]]; then
        log_warning ".secrets.local not found. Creating from example..."
        cp .secrets.local.example .secrets.local
        log_info "Please edit .secrets.local with your values"
    fi
}

# Test individual jobs
test_security_scan() {
    log_info "Testing security scan job..."
    act -j security-scan --env RUN_LOCAL=true --dry-run
    log_success "Security scan test completed"
}

test_unit_tests() {
    log_info "Testing unit tests job..."
    act -j test --env RUN_LOCAL=true --dry-run
    log_success "Unit tests job test completed"
}

test_build() {
    log_info "Testing build job..."
    act -j build --env RUN_LOCAL=true --dry-run
    log_success "Build job test completed"
}

# Test deployment workflows
test_dev_deployment() {
    log_info "Testing development deployment..."
    act push \
        --env RUN_LOCAL=true \
        --eventpath .github/events/develop-push.json \
        --job deploy-dev \
        --dry-run
    log_success "Development deployment test completed"
}

test_staging_deployment() {
    log_info "Testing staging deployment..."
    act push \
        --env RUN_LOCAL=true \
        --eventpath .github/events/main-push.json \
        --job deploy-staging \
        --dry-run
    log_success "Staging deployment test completed"
}

test_production_deployment() {
    log_info "Testing production deployment..."
    act release \
        --env RUN_LOCAL=true \
        --eventpath .github/events/release-published.json \
        --job deploy-production \
        --dry-run
    log_success "Production deployment test completed"
}

# Full pipeline test
test_full_pipeline() {
    log_info "Testing full CI pipeline (no deployment)..."
    act push \
        --env RUN_LOCAL=true \
        --job security-scan \
        --job test \
        --job build \
        --job container-scan \
        --dry-run
    log_success "Full pipeline test completed"
}

# Show help
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  security         Test security scan job"
    echo "  test             Test unit tests job"
    echo "  build            Test build job" 
    echo "  deploy-dev       Test development deployment"
    echo "  deploy-staging   Test staging deployment"
    echo "  deploy-prod      Test production deployment"
    echo "  full             Test full CI pipeline"
    echo "  list             List all available jobs"
    echo "  help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 security      # Run security scan test"
    echo "  $0 full          # Run full pipeline test"
    echo "  $0 deploy-dev    # Test dev deployment workflow"
}

# List all jobs
list_jobs() {
    log_info "Listing all available jobs in CI/CD workflow..."
    act --list
}

# Main execution
main() {
    log_info "🚀 GitHub Actions Local Testing with Act"
    
    # Pre-flight checks
    check_act_installed
    check_config_files
    
    case "${1:-help}" in
        "security")
            test_security_scan
            ;;
        "test")
            test_unit_tests
            ;;
        "build")
            test_build
            ;;
        "deploy-dev")
            test_dev_deployment
            ;;
        "deploy-staging")
            test_staging_deployment
            ;;
        "deploy-prod")
            test_production_deployment
            ;;
        "full")
            test_full_pipeline
            ;;
        "list")
            list_jobs
            ;;
        "help"|*)
            show_help
            ;;
    esac
    
    log_success "🎉 Testing completed!"
}

# Change to script directory
cd "$(dirname "$0")/.."

# Run main function with all arguments
main "$@"