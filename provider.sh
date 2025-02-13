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

# Function to retry operations
retry_operation() {
    local cmd="$1"
    local description="$2"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        print_status "Attempt $attempt of $max_attempts: $description"
        if eval "$cmd"; then
            return 0
        else
            if [ $attempt -eq $max_attempts ]; then
                print_error "Failed after $max_attempts attempts: $description"
            fi
            print_status "Retrying in 5 seconds..."
            sleep 5
        fi
        ((attempt++))
    done
    return 1
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

# Function to get provider choice with retries
get_provider_choice() {
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        print_status "Attempt $attempt of $max_attempts: Choose your cloud provider"
        echo -e "${BLUE}1) AWS${NC}"
        echo -e "${BLUE}2) Azure${NC}"
        echo -e "${BLUE}3) GCP${NC}"

        read -p "Enter your choice (1-3): " choice
        echo ""

        case $choice in
            1|2|3) return $choice;;
            *)
                if [ $attempt -eq $max_attempts ]; then
                    print_error "Failed after $max_attempts attempts: Invalid choice. Please select 1, 2, or 3."
                fi
                print_status "Invalid choice. Please select 1, 2, or 3."
                echo ""
                ((attempt++))
                ;;
        esac
    done
}

# Get provider choice with retries
get_provider_choice
choice=$?

case $choice in
    1)
        print_status "You have selected AWS"
        echo ""

        print_status "Installing AWS provider..."
        retry_operation "cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v1
EOF" "Installing AWS provider"
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

        retry_operation "cat <<EOF | kubectl apply -f -
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
EOF" "Creating AWS ProviderConfig"
        print_success "AWS ProviderConfig created successfully"
        echo ""
        ;;
    2)
        print_status "You have selected Azure"
        print_status "Installing Azure provider..."
        retry_operation "cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v1
EOF" "Installing Azure provider"
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

        retry_operation "cat <<EOF | kubectl apply -f -
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
EOF" "Creating Azure ProviderConfig"
        print_success "Azure ProviderConfig created successfully"
        echo ""
        ;;
    3)
        print_status "You have selected GCP"
        print_status "Installing GCP provider..."
        retry_operation "cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp-storage
spec:
  package: xpkg.upbound.io/upbound/provider-gcp-storage:v1
EOF" "Installing GCP provider"
        print_success "Provider installed successfully"
        echo ""

        # Create GCP credentials secret
        print_status "GCP Credentials Setup"
        
        # Get GCP project ID
        read -p "Enter your GCP Project ID: " GCP_PROJECT
        
        # Get service account name
        read -p "Enter service account name [default: crossplane-sa]: " sa_name
        sa_name=${sa_name:-crossplane-sa}

        # Select role
        print_status "Choose role for service account:"
        echo -e "${BLUE}1) Owner (Full access)${NC}"
        echo -e "${BLUE}2) Editor (Modify access)${NC}"
        read -p "Enter your choice (1-2) [default: 1]: " role_choice
        role_choice=${role_choice:-1}

        case $role_choice in
            1) role="roles/owner";;
            2) role="roles/editor";;
            *) print_error "Invalid role choice";;
        esac

        print_status "Checking for existing service account: $sa_name"
        if gcloud iam service-accounts list --project="$GCP_PROJECT" --filter="email:$sa_name@$GCP_PROJECT.iam.gserviceaccount.com" --format="get(email)" | grep -q "$sa_name@$GCP_PROJECT.iam.gserviceaccount.com"; then
            print_status "Service account $sa_name already exists"
        else
            print_status "Creating service account: $sa_name"
            if ! gcloud iam service-accounts create "$sa_name" \
                --project="$GCP_PROJECT" 2>/dev/null; then
                print_error "Failed to create service account"
            fi
            print_success "Service account created successfully"
        fi

        print_status "Assigning role: $role"
        if ! gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
            --member="serviceAccount:$sa_name@$GCP_PROJECT.iam.gserviceaccount.com" \
            --role="$role" 2>/dev/null; then
            print_error "Failed to assign role"
        fi

        print_status "Creating service account key"
        if ! gcloud iam service-accounts keys create creds.json \
            --iam-account="$sa_name@$GCP_PROJECT.iam.gserviceaccount.com" 2>/dev/null; then
            print_error "Failed to create service account key"
        fi

        gcp_creds_path="creds.json"
        print_success "Service account key created: $gcp_creds_path"

        # Create or update Kubernetes secret
        print_status "Creating GCP credentials secret..."
        if kubectl get secret gcp-secret -n crossplane-system &>/dev/null; then
            print_status "Updating existing GCP credentials secret"
            kubectl delete secret gcp-secret -n crossplane-system
        fi
        
        # Create Kubernetes secret from credentials
        if ! kubectl create secret generic gcp-secret \
            -n crossplane-system \
            --from-file=creds="$gcp_creds_path"; then
            print_error "Failed to create Kubernetes secret"
        fi
        print_success "GCP credentials secret created in Kubernetes"
        rm creds.json
        echo ""

        # Create GCP ProviderConfig
        print_status "Creating GCP ProviderConfig..."
        sleep 10

        retry_operation "cat <<EOF | kubectl apply -f -
apiVersion: gcp.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-secret
      key: creds
  projectID: "$GCP_PROJECT"
EOF" "Creating GCP ProviderConfig"
        print_success "GCP ProviderConfig created successfully"
        echo ""
        ;;
    *)
        print_error "Invalid choice. Please select 1, 2, or 3."
        ;;
esac

print_success "Script executed successfully"
