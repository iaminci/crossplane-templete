#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${BLUE}===> ${NC}$1"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}SUCCESS: ${NC}$1"
}

# Function to print error messages
print_error() {
    echo -e "${RED}ERROR: ${NC}$1"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}WARNING: ${NC}$1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to uninstall Crossplane
uninstall_crossplane() {
    if command_exists helm; then
        print_status "Uninstalling Crossplane..."
        
        # Check if crossplane namespace exists
        if kubectl get namespace crossplane-system >/dev/null 2>&1; then
            # Uninstall crossplane helm release
            helm uninstall crossplane --namespace crossplane-system
            
            # Delete the namespace
            kubectl delete namespace crossplane-system
            
            # Remove crossplane helm repo
            helm repo remove crossplane-stable
            
            print_success "Crossplane uninstalled successfully"
        else
            print_warning "Crossplane namespace not found, skipping Crossplane uninstallation"
        fi
    else
        print_warning "Helm not found, skipping Crossplane uninstallation"
    fi
}

# Function to delete k3d clusters
delete_clusters() {
    if command_exists k3d; then
        print_status "Deleting all k3d clusters..."
        # Get all clusters
        clusters=$(k3d cluster list -o json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$clusters" ]; then
            for cluster in $clusters; do
                print_status "Deleting cluster: $cluster"
                k3d cluster delete "$cluster"
            done
            print_success "All clusters deleted successfully"
        else
            print_warning "No k3d clusters found"
        fi
    else
        print_warning "k3d is not installed, skipping cluster deletion"
    fi
}

# Function to remove k3d binary
remove_k3d() {
    if command_exists k3d; then
        print_status "Removing k3d binary..."
        # k3d is typically installed in /usr/local/bin
        rm -f $(which k3d)
        if [ $? -eq 0 ]; then
            print_success "k3d binary removed successfully"
        else
            print_error "Failed to remove k3d binary"
            exit 1
        fi
    else
        print_warning "k3d is not installed, skipping binary removal"
    fi
}

# Function to clean up k3d directories and configurations
cleanup_directories() {
    # Define the k3d directory
    K3D_DIR="$HOME/k3d"

    print_status "Cleaning up k3d directories and configurations..."

    # Remove k3d directory if it exists
    if [ -d "$K3D_DIR" ]; then
        print_status "Removing k3d directory: $K3D_DIR"
        rm -rf "$K3D_DIR"
        if [ $? -eq 0 ]; then
            print_success "k3d directory removed successfully"
        else
            print_error "Failed to remove k3d directory"
            exit 1
        fi
    else
        print_warning "k3d directory not found, skipping"
    fi

    # Clean up Docker resources related to k3d
    if command_exists docker; then
        print_status "Cleaning up k3d-related Docker resources..."
        
        # Remove k3d images
        docker images | grep 'k3d' | awk '{print $3}' | xargs -r docker rmi -f
        
        # Remove k3d volumes
        docker volume ls | grep 'k3d' | awk '{print $2}' | xargs -r docker volume rm
        
        print_success "Docker cleanup completed"
    fi
}

# Function to remove kubectl configuration for k3d clusters
cleanup_kubeconfig() {
    if [ -f "$HOME/.kube/config" ]; then
        print_status "Cleaning up kubectl configuration..."
        
        # Backup current kubeconfig
        cp "$HOME/.kube/config" "$HOME/.kube/config.backup_$(date +%Y%m%d_%H%M%S)"
        
        # Remove k3d related contexts and clusters
        KUBECONFIG="$HOME/.kube/config"
        contexts=$(kubectl config get-contexts -o name | grep 'k3d')
        for context in $contexts; do
            kubectl config delete-context "$context"
        done
        
        clusters=$(kubectl config get-clusters | grep 'k3d')
        for cluster in $clusters; do
            kubectl config delete-cluster "$cluster"
        done
        
        print_success "kubectl configuration cleaned up"
    else
        print_warning "No kubectl configuration found, skipping"
    fi
}

# Main execution
print_status "Starting uninstallation process..."

# Confirm before proceeding
read -p "$(echo -e "${YELLOW}This will remove Crossplane, k3d, all clusters, and related configurations. Continue? (Y/n): ${NC}")" confirm
if [[ "$confirm" =~ ^[nN]$ ]]; then
    print_warning "Uninstallation cancelled"
    exit 0
fi

# Execute uninstallation steps in reverse order
uninstall_crossplane
delete_clusters
remove_k3d
cleanup_directories
cleanup_kubeconfig

print_success "Uninstallation completed successfully"
print_warning "Note: A backup of your kubectl config has been created if it was modified"