#!/bin/bash
set -e

echo "Before install script - preparing for deployment"

# Define variables
CLUSTER_NAME=${CLUSTER_NAME:-spring-boot-eks-cluster}
REGION=${AWS_REGION:-us-east-1}
NAMESPACE="spring-boot"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Installing AWS CLI..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
fi

# Configure kubectl to use the EKS cluster
echo "Configuring kubectl to use EKS cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}

# Verify connection to the cluster
echo "Verifying connection to the cluster..."
kubectl get nodes

# Create namespace if it doesn't exist
if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
    echo "Creating namespace: ${NAMESPACE}"
    kubectl apply -f kubernetes/namespace.yaml
else
    echo "Namespace ${NAMESPACE} already exists"
fi

echo "Pre-deployment preparation completed successfully"