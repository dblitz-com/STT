#!/bin/bash
# GitHub Actions Runner Controller Installation Script
#
# This script deploys GitHub Actions self-hosted runners in Kubernetes
# using actions-runner-controller (ARC).
#
# Usage: ./install.sh [GITHUB_TOKEN] [REPOSITORY]
# Example: ./install.sh ghp_xxxxxxxxxxxx dBlitz37/dblitz-engine

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for deployment to be ready
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    print_status "Waiting for deployment $deployment in namespace $namespace to be ready..."
    
    if kubectl wait --for=condition=Available --timeout=${timeout}s deployment/$deployment -n $namespace; then
        print_success "Deployment $deployment is ready"
        return 0
    else
        print_error "Deployment $deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

# Function to wait for CRDs to be established
wait_for_crds() {
    print_status "Waiting for CRDs to be established..."
    
    local crds=(
        "runners.actions.summerwind.dev"
        "runnerdeployments.actions.summerwind.dev" 
        "runnerreplicasets.actions.summerwind.dev"
        "horizontalrunnerautoscalers.actions.summerwind.dev"
    )
    
    for crd in "${crds[@]}"; do
        print_status "Waiting for CRD $crd..."
        kubectl wait --for=condition=Established --timeout=60s crd/$crd
    done
    
    print_success "All CRDs are established"
}

# Main installation function
main() {
    print_status "Starting GitHub Actions Runner Controller installation..."
    
    # Check prerequisites
    if ! command_exists kubectl; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command_exists base64; then
        print_error "base64 command is not available"
        exit 1
    fi
    
    # Check kubectl access
    if ! kubectl auth can-i create namespaces; then
        print_error "Insufficient permissions. Need cluster admin access."
        exit 1
    fi
    
    # Get GitHub token
    GITHUB_TOKEN=${1:-}
    if [ -z "$GITHUB_TOKEN" ]; then
        print_warning "GitHub token not provided as argument"
        read -sp "Enter GitHub Personal Access Token: " GITHUB_TOKEN
        echo
    fi
    
    if [ -z "$GITHUB_TOKEN" ]; then
        print_error "GitHub token is required"
        exit 1
    fi
    
    # Get repository
    REPOSITORY=${2:-}
    if [ -z "$REPOSITORY" ]; then
        print_warning "Repository not provided as argument"
        read -p "Enter repository (format: owner/repo): " REPOSITORY
    fi
    
    if [ -z "$REPOSITORY" ]; then
        print_error "Repository is required"
        exit 1
    fi
    
    # Validate repository format
    if [[ ! "$REPOSITORY" =~ ^[^/]+/[^/]+$ ]]; then
        print_error "Repository must be in format 'owner/repo'"
        exit 1
    fi
    
    print_status "Installing for repository: $REPOSITORY"
    
    # Create temporary files with token and repository
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    # Copy files to temp directory and replace placeholders
    cp *.yaml "$TEMP_DIR/"
    
    # Replace GitHub token in actions-runner-controller.yaml
    ENCODED_TOKEN=$(echo -n "$GITHUB_TOKEN" | base64)
    sed -i.bak "s/REPLACE_WITH_BASE64_ENCODED_GITHUB_TOKEN/$ENCODED_TOKEN/g" "$TEMP_DIR/actions-runner-controller.yaml"
    
    # Replace repository in runner-deployment.yaml
    sed -i.bak "s|dBlitz37/dblitz-engine|$REPOSITORY|g" "$TEMP_DIR/runner-deployment.yaml"
    
    # Step 1: Install cert-manager
    print_status "Installing cert-manager..."
    kubectl apply -f "$TEMP_DIR/cert-manager.yaml"
    
    # Wait for cert-manager namespace
    sleep 5
    if kubectl get namespace cert-manager >/dev/null 2>&1; then
        print_status "Waiting for cert-manager installation to complete..."
        sleep 30  # Give time for the installation job to run
    fi
    
    # Step 2: Install CRDs
    print_status "Installing ARC Custom Resource Definitions..."
    kubectl apply -f "$TEMP_DIR/arc-crds.yaml"
    wait_for_crds
    
    # Step 3: Install ARC controller
    print_status "Installing Actions Runner Controller..."
    kubectl apply -f "$TEMP_DIR/actions-runner-controller.yaml"
    
    # Wait for ARC controller to be ready
    sleep 10
    wait_for_deployment "actions-runner-system" "controller-manager" 300
    
    # Step 4: Deploy runners
    print_status "Deploying GitHub Actions runners..."
    kubectl apply -f "$TEMP_DIR/runner-deployment.yaml"
    
    # Wait for runner deployment
    sleep 10
    print_status "Waiting for runners to be ready..."
    
    # Check runner deployment status
    for i in {1..30}; do
        if kubectl get runnerdeployment claude-code-runners -n actions-runner-system >/dev/null 2>&1; then
            print_success "RunnerDeployment created successfully"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "RunnerDeployment creation timed out"
            exit 1
        fi
        sleep 10
    done
    
    # Show final status
    print_success "GitHub Actions Runner Controller installation completed!"
    print_status "Checking final status..."
    
    echo
    print_status "Namespaces:"
    kubectl get namespaces | grep -E "(cert-manager|actions-runner-system)"
    
    echo
    print_status "ARC Controller:"
    kubectl get pods -n actions-runner-system
    
    echo  
    print_status "Runner Deployments:"
    kubectl get runnerdeployments -n actions-runner-system
    
    echo
    print_status "Runners:"
    kubectl get runners -n actions-runner-system
    
    echo
    print_status "Autoscalers:"
    kubectl get horizontalrunnerautoscalers -n actions-runner-system
    
    echo
    print_success "Installation complete! Runners should appear in GitHub repository settings > Actions > Runners"
    print_status "Repository: https://github.com/$REPOSITORY/settings/actions/runners"
    
    echo
    print_status "To test the runners, create a workflow that uses:"
    print_status "  runs-on: [self-hosted, linux, x64, claude-code]"
    
    echo
    print_status "To monitor logs:"
    print_status "  kubectl logs -f deployment/controller-manager -n actions-runner-system"
    print_status "  kubectl logs -f deployment/claude-code-runners -n actions-runner-system"
}

# Run main function
main "$@"