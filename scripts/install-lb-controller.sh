#!/bin/bash
set -e

# This script installs the AWS Load Balancer Controller on an EKS cluster

# Check if cluster name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <cluster-name> <aws-region>"
  exit 1
fi

CLUSTER_NAME=$1
AWS_REGION=${2:-us-east-1}

# Get the EKS cluster VPC ID
VPC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

# Get the OIDC provider URL
OIDC_PROVIDER=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# Create IAM policy for the AWS Load Balancer Controller
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='AWSLoadBalancerControllerIAMPolicy'].Arn" --output text)

if [ -z "$POLICY_ARN" ]; then
  echo "Creating IAM policy for AWS Load Balancer Controller..."
  curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.7/docs/install/iam_policy.json
  
  POLICY_ARN=$(aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam-policy.json \
    --query "Policy.Arn" \
    --output text)
  
  rm iam-policy.json
else
  echo "IAM policy for AWS Load Balancer Controller already exists."
fi

# Create IAM role and service account for the AWS Load Balancer Controller
echo "Creating service account for AWS Load Balancer Controller..."
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=$POLICY_ARN \
  --override-existing-serviceaccounts \
  --approve \
  --region $AWS_REGION

# Install the AWS Load Balancer Controller using Helm
echo "Adding Helm repository for AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "Installing AWS Load Balancer Controller..."
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$AWS_REGION \
  --set vpcId=$VPC_ID \
  --namespace kube-system

echo "AWS Load Balancer Controller installation completed."

# Verify the installation
echo "Verifying the installation..."
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller