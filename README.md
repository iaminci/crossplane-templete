# Crossplane Infrastructure Setup

A collection of shell scripts to set up and manage Crossplane for infrastructure management.

## Scripts Overview

### install.sh
An interactive installation script that allows you to:
- Install k3d (a lightweight Kubernetes cluster that runs in Docker)
- Install Crossplane (a Kubernetes-native infrastructure provider)
- Install both components together

The script includes:
- Pre-requisite checks for required tools (curl, helm, docker)
- k3d cluster configuration and setup
- Crossplane installation via Helm
- Interactive prompts with multiple retry attempts for reliability

### provider.sh
Configures cloud provider integration with Crossplane. Features:
- Interactive provider selection (AWS, Azure, or GCP)
- Secure credential management
- Automatic provider installation and configuration
- Support for:
  - AWS S3 provider
  - Azure Network provider
  - GCP Storage provider
- Handles creation of:
  - Provider resources
  - Kubernetes secrets for credentials
  - Provider configurations

### uninstall.sh
Comprehensive cleanup script that can:
- Remove Crossplane installations
- Delete k3d clusters
- Clean up k3d binary and configurations
- Remove provider configurations
- Backup and clean kubectl configurations
- Clean up related Docker resources

## Prerequisites

Required Tools:
- curl - For downloading components
- Docker - For running k3d and containers
- kubectl - For managing Kubernetes resources
- Helm - For installing Crossplane

Cloud Provider Requirements (based on your choice):
- For AWS:
  - AWS CLI
  - AWS Account
  - AWS Access Key ID and Secret Access Key with appropriate permissions
- For Azure:
  - Azure CLI
  - Azure Account
  - Azure Subscription ID
  - Permissions to create service principals
- For GCP:
  - Google Cloud SDK (gcloud)
  - GCP Account
  - GCP Project
  - Permissions to create service accounts and assign roles

System Requirements:
- Operating System: Linux, macOS, or Windows with WSL2
- Sufficient disk space for Docker images and Kubernetes components
- Internet connection for downloading components and cloud provider access

## Usage

1. Start with installation:
```bash
./install.sh
```

2. Configure your cloud provider:
```bash
./provider.sh
```

3. When needed, clean up all resources:
```bash
./uninstall.sh
```
