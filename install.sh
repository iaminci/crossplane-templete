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
    exit 1
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}WARNING: ${NC}$1"
}

# Function to check command existence
check_command() {
    if ! command -v $1 >/dev/null 2>&1; then
        print_error "$1 is not installed. Please install $1 first."
    fi
}

# Pre-requisite checks
check_command curl
check_command helm
check_command docker

# K3d installation
install_k3d() {
    # Check if k3d is already installed
    if command -v k3d >/dev/null 2>&1; then
        CURRENT_VERSION=$(k3d version | head -n 1)
        print_warning "k3d is already installed."
        print_status "Current version: $CURRENT_VERSION"
        return 0
    fi

    # Install k3d
    print_status "Installing k3d..."
    if curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash; then
        print_success "k3d installation completed successfully"
        return 0
    else
        print_error "Failed to install k3d"
    fi
}

# Configuring k3d
configure_k3d() {
    # Define the k3d directory
    K3D_DIR="$HOME/k3d"

    # Check and create main k3d directory
    if [ ! -d "$K3D_DIR" ]; then
        print_status "Creating k3d directory..."
        mkdir -p "$K3D_DIR" || {
            print_error "Failed to create k3d directory"
        }
        print_success "Successfully created k3d directory"
        print_status "Directory: $K3D_DIR"
    else
        print_warning "k3d directory already exists at $K3D_DIR"
    fi

    # Check and create mnt subdirectory
    if [ ! -d "$K3D_DIR/mnt" ]; then
        print_status "Creating mnt directory..."
        mkdir -p "$K3D_DIR/mnt" || {
            print_error "Failed to create mnt directory"
        }
        print_success "Successfully created mnt directory"
        print_status "Directory: $K3D_DIR/mnt"
    else
        print_warning "mnt directory already exists"
    fi

    # Check if config.yaml exists and create if it doesn't
    if [ ! -f "$K3D_DIR/config.yaml" ]; then
        print_status "Creating k3d configuration file..."
        cat << EOF > "$K3D_DIR/config.yaml"
apiVersion: k3d.io/v1alpha5
kind: Simple
metadata:
  name: k3d
servers: 1
agents: 1
kubeAPI:
  hostIP: "0.0.0.0"
  hostPort: "6445"
volumes:
  - volume: $K3D_DIR/mnt:/mnt
    nodeFilters:
      - server:0
      - agent:*
options:
  k3d:
    wait: true
    timeout: "60s"
    disableLoadbalancer: false
    disableImageVolume: false
    disableRollback: true
EOF
        if [ $? -eq 0 ]; then
            print_success "Successfully created config.yaml"
        else
            print_error "Failed to create config.yaml"
        fi
    else
        print_warning "config.yaml already exists"
    fi
}

# k3d cluster creation
create_cluster() {
    # Check if config.yaml exists
    K3D_DIR="$HOME/k3d"
    if [ ! -f "$K3D_DIR/config.yaml" ]; then
        print_error "Configuration file not found"
    fi

    # Create k3d cluster
    print_status "Creating k3d cluster..."
    k3d cluster create crossplane --config "$K3D_DIR/config.yaml"

    if [ $? -eq 0 ]; then
        print_success "Successfully created k3d cluster"
        # Verify cluster status
        print_status "Verifying cluster status..."
        kubectl cluster-info
    else
        print_error "Failed to create k3d cluster"
    fi
}

# Adding crossplane helm repo
add_helm_repo() {
    print_status "Adding crossplane helm repo..."
    helm repo add crossplane-stable https://charts.crossplane.io/stable
    helm repo update
    print_success "Crossplane helm repo added successfully"
}

# Install crossplane
install_crossplane() {
    print_status "Installing crossplane..."
    helm install crossplane crossplane-stable/crossplane --namespace crossplane-system --create-namespace
    print_success "Crossplane installed successfully"
}

# Function to install k3d component
install_k3d_component() {
    print_status "Starting k3d setup process..."
    install_k3d
    configure_k3d
    create_cluster
    print_success "k3d setup completed successfully"
}

# Function to install crossplane component
install_crossplane_component() {
    print_status "Starting crossplane installation..."
    add_helm_repo
    install_crossplane
    print_success "Crossplane installation completed successfully"
}

# Main execution
attempts=0
max_attempts=3

while true; do
    echo "Available components:"
    echo "1) k3d"
    echo "2) crossplane"
    echo "3) all"

    read -p "Enter the number of the component to install (1/2/3): " choice

    # Validate input
    if [[ ! "$choice" =~ ^[1-3]$ ]]; then
        ((attempts++))
        remaining=$((max_attempts - attempts))
        if [ $remaining -eq 0 ]; then
            print_error "Maximum attempts reached. Exiting script."
            exit 1
        fi
        print_error "Invalid choice. Please select 1, 2, or 3. ($remaining attempts remaining)"
        continue
    fi

    # Show what will be installed based on choice
    echo -e "\nYou have selected to install:"
    case $choice in
        1) echo "- k3d" ;;
        2) echo "- Crossplane" ;;
        3) echo "- ALL components (k3d and Crossplane)" ;;
    esac

    # Confirm before proceeding
    echo
    confirm_attempts=0
    max_confirm_attempts=3
    
    while true; do
        read -p "$(echo -e "${YELLOW}Are you sure you want to proceed with installation? (Y/n): ${NC}")" confirm
        
        if [[ "$confirm" =~ ^[YyNn]$ ]]; then
            if [[ "$confirm" =~ ^[Nn]$ ]]; then
                print_warning "Installation cancelled"
                exit 0
            fi
            break
        else
            ((confirm_attempts++))
            remaining=$((max_confirm_attempts - confirm_attempts))
            if [ $remaining -eq 0 ]; then
                print_error "Maximum confirmation attempts reached. Exiting script."
                exit 1
            fi
            echo -e "${RED}ERROR: ${NC}Invalid input. Please enter 'y' or 'n'. ($remaining attempts remaining)"
            continue
        fi
    done
    break
done

case $choice in
    1)
        install_k3d_component
        ;;
    2)
        install_crossplane_component
        ;;
    3)
        install_k3d_component
        install_crossplane_component
        ;;
esac
