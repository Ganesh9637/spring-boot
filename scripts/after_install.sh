#!/bin/bash
set -e

echo "After install script - deployment completed"

# Define variables
CLUSTER_NAME=${CLUSTER_NAME:-spring-boot-eks-cluster}
REGION=${AWS_REGION:-us-east-1}
NAMESPACE="spring-boot"
DEPLOYMENT_NAME="spring-boot-app"
MAX_RETRY=10
RETRY_INTERVAL=30

# Configure kubectl to use the EKS cluster if not already configured
if ! kubectl get nodes &> /dev/null; then
    echo "Configuring kubectl to use EKS cluster: ${CLUSTER_NAME}"
    aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}
fi

# Apply the Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f kubernetes/deployment.yaml
kubectl apply -f kubernetes/service.yaml

# Wait for deployment to complete
echo "Waiting for deployment to complete..."
kubectl rollout status deployment/${DEPLOYMENT_NAME} -n ${NAMESPACE} --timeout=300s

# Verify the deployment
echo "Verifying deployment..."
READY=$(kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
DESIRED=$(kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')

if [ "$READY" -eq "$DESIRED" ]; then
    echo "Deployment successful: ${READY}/${DESIRED} pods are ready"
else
    echo "Deployment failed: Only ${READY}/${DESIRED} pods are ready"
    exit 1
fi

# Get the service details
echo "Getting service details..."
kubectl get service ${DEPLOYMENT_NAME} -n ${NAMESPACE}

# Wait for the load balancer to be provisioned
echo "Waiting for load balancer to be provisioned..."
for i in $(seq 1 $MAX_RETRY); do
    LB_HOSTNAME=$(kubectl get service ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [ -n "$LB_HOSTNAME" ]; then
        echo "Load balancer provisioned: $LB_HOSTNAME"
        break
    fi
    
    if [ $i -eq $MAX_RETRY ]; then
        echo "Timed out waiting for load balancer to be provisioned"
        exit 1
    fi
    
    echo "Waiting for load balancer... (Attempt $i/$MAX_RETRY)"
    sleep $RETRY_INTERVAL
done

echo "Post-deployment tasks completed successfully"