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

# Function to get valid y/n input
get_yes_no() {
    local prompt="$1"
    local response
    while true; do
        read -p "$prompt" response
        response=${response:-y}  # Default to 'y' if Enter is pressed
        case $response in
            [Yy]* ) return 0;;  # Return 0 for yes
            [Nn]* ) return 1;;  # Return 1 for no
            * ) echo "Please answer 'y' or 'n'";;
        esac
    done
}

print_status "Choose your cloud provider:"
echo -e "${BLUE}1) AWS${NC}"
echo -e "${BLUE}2) Azure${NC}"
echo -e "${BLUE}3) GCP${NC}"

read -p "Enter your choice (1-3): " choice
echo ""

case $choice in
    1)
        print_status "You have selected AWS"
        echo ""

        print_status "Installing AWS provider..."
        cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1
EOF
        print_success "Provider installed successfully"
        echo ""

        # Create AWS credentials secret
        print_status "Creating AWS credentials secret..."
        # print_status "Checking for existing AWS credentials secret..."
        if kubectl get secret aws-secret -n crossplane-system &>/dev/null; then
            print_status "AWS credentials secret already exists"
            if get_yes_no "Press Enter to use existing secret or type 'n' to create new credentials: "; then
                print_success "Using existing AWS credentials secret"
                echo ""
            else
                # Get AWS credentials from user
                kubectl delete secret aws-secret -n crossplane-system
                read -p "Enter your AWS Access Key ID: " aws_access_key
                read -p "Enter your AWS Secret Access Key: " aws_secret_key

                # Create aws-credentials.txt file
                cat > aws-credentials.txt << EOF
[default]
aws_access_key_id = $aws_access_key
aws_secret_access_key = $aws_secret_key
EOF
                # Create Kubernetes secret from credentials
                kubectl create secret \
                generic aws-secret \
                -n crossplane-system \
                --from-file=creds=./aws-credentials.txt
                # Remove aws-credentials.txt file
                rm aws-credentials.txt
                print_success "AWS credentials secret created in Kubernetes"
                echo ""
            fi
        else
            # Get AWS credentials from user
            read -p "Enter your AWS Access Key ID: " aws_access_key
            read -p "Enter your AWS Secret Access Key: " aws_secret_key

            # Create aws-credentials.txt file
            cat > aws-credentials.txt << EOF
[default]
aws_access_key_id = $aws_access_key
aws_secret_access_key = $aws_secret_key
EOF
            # Create Kubernetes secret from credentials
            kubectl create secret \
            generic aws-secret \
            -n crossplane-system \
            --from-file=creds=./aws-credentials.txt
            # Remove aws-credentials.txt file
            rm aws-credentials.txt
            print_success "AWS credentials secret created in Kubernetes"
            echo ""
        fi

        # Create AWS ProviderConfig
        print_status "Creating AWS ProviderConfig..."
        sleep 10

        cat <<EOF | kubectl apply -f -
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-secret
      key: creds
EOF
        print_success "AWS ProviderConfig created successfully"
        echo ""
        ;;
    2)
        print_status "You have selected Azure"
        print_status "Installing Azure provider..."
        cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v1
EOF
        print_success "Provider installed successfully"
        echo ""

        # Create Azure credentials secret
        print_status "Creating Azure credentials secret..."
        if kubectl get secret azure-secret -n crossplane-system &>/dev/null; then
            print_status "Azure credentials secret already exists"
            if get_yes_no "Press Enter to use existing secret or type 'n' to create new credentials: "; then
                print_success "Using existing Azure credentials secret"
                echo ""
            else
                # Delete existing secret and create new one
                kubectl delete secret azure-secret -n crossplane-system
                read -p "Enter your Azure Subscription ID: " azure_sub_id
                print_status "Creating new service principal with Owner role..."
                az ad sp create-for-rbac --sdk-auth --role Owner --scopes /subscriptions/$azure_sub_id > azure-credentials.json
                # Create Kubernetes secret from credentials
                kubectl create secret generic azure-secret -n crossplane-system --from-file=creds=./azure-credentials.json
                # Remove azure-credentials.json file
                rm azure-credentials.json
                print_success "Azure credentials secret created in Kubernetes"
                echo ""
            fi
        else
            read -p "Enter your Azure Subscription ID: " azure_sub_id
            print_status "Creating new service principal with Owner role..."
            az ad sp create-for-rbac --sdk-auth --role Owner --scopes /subscriptions/$azure_sub_id > azure-credentials.json
            # Create Kubernetes secret from credentials
            kubectl create secret generic azure-secret -n crossplane-system --from-file=creds=./azure-credentials.json
            # Remove azure-credentials.json file
            rm azure-credentials.json
            print_success "Azure credentials secret created in Kubernetes"
            echo ""
        fi

        # Create Azure ProviderConfig
        print_status "Creating Azure ProviderConfig..."
        sleep 10

        cat <<EOF | kubectl apply -f -
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-secret
      key: creds
EOF
        print_success "Azure ProviderConfig created successfully"
        echo ""
        ;;
    3)
        print_status "You have selected GCP"
        print_status "Installing GCP provider..."
        cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp-storage
spec:
  package: xpkg.upbound.io/upbound/provider-gcp-storage:v1
EOF
        print_success "Provider installed successfully"
        ;;
    *)
        print_error "Invalid choice. Please select 1, 2, or 3."
        ;;
esac

print_success "Script executed successfully"
