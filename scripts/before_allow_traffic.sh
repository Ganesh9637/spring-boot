#!/bin/bash
set -e

echo "Before allow traffic script - preparing for production traffic"

# Define variables
NAMESPACE="spring-boot"
DEPLOYMENT_NAME="spring-boot-app"
MIN_READY_PODS=2

# Check if all pods are ready
echo "Checking if all pods are ready..."
READY_PODS=$(kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
DESIRED_PODS=$(kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.replicas}')

echo "Ready pods: $READY_PODS/$DESIRED_PODS"

if [ "$READY_PODS" -lt "$MIN_READY_PODS" ]; then
    echo "Error: Not enough pods are ready. Expected at least $MIN_READY_PODS, got $READY_PODS"
    exit 1
fi

# Check pod resource usage
echo "Checking pod resource usage..."
kubectl top pods -n ${NAMESPACE} --containers || echo "kubectl top not available, skipping resource check"

# Check for any warnings or errors in the logs
echo "Checking for errors in the logs..."
ERROR_COUNT=$(kubectl logs -n ${NAMESPACE} -l app=${DEPLOYMENT_NAME} --tail=100 | grep -i "error\|exception\|fail" | wc -l)

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "Warning: Found $ERROR_COUNT potential errors in the logs"
    kubectl logs -n ${NAMESPACE} -l app=${DEPLOYMENT_NAME} --tail=100 | grep -i "error\|exception\|fail"
    # Not failing the deployment, just warning
fi

# Check if the service is properly configured
echo "Checking service configuration..."
kubectl get service ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o yaml

# Check if the load balancer is provisioned
echo "Checking load balancer status..."
LB_HOSTNAME=$(kubectl get service ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LB_HOSTNAME" ]; then
    echo "Warning: Load balancer hostname is not available yet"
else
    echo "Load balancer hostname: $LB_HOSTNAME"
fi

# Set up any pre-production traffic tasks here
# For example, warming up caches, pre-loading data, etc.

echo "Pre-production traffic preparation completed successfully"