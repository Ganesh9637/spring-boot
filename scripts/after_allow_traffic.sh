#!/bin/bash
set -e

echo "After allow traffic script - application is now receiving production traffic"

# Define variables
NAMESPACE="spring-boot"
DEPLOYMENT_NAME="spring-boot-app"
REGION=${AWS_REGION:-us-east-1}
APP_NAME="spring-boot-app"
ENVIRONMENT="production"

# Get the load balancer hostname
LB_HOSTNAME=$(kubectl get service ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LB_HOSTNAME" ]; then
    echo "Warning: Load balancer hostname is not available"
else
    echo "Application is accessible at: http://${LB_HOSTNAME}"
fi

# Get deployment details
echo "Deployment details:"
kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o wide

# Get pod details
echo "Pod details:"
kubectl get pods -n ${NAMESPACE} -l app=${DEPLOYMENT_NAME} -o wide

# Get service details
echo "Service details:"
kubectl get service ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o wide

# Set up CloudWatch alarms for the application
if command -v aws &> /dev/null; then
    echo "Setting up CloudWatch alarms..."
    
    # Create a CloudWatch alarm for high CPU usage
    aws cloudwatch put-metric-alarm \
        --alarm-name "${APP_NAME}-${ENVIRONMENT}-high-cpu" \
        --alarm-description "Alarm when CPU usage is high" \
        --metric-name CPUUtilization \
        --namespace AWS/ECS \
        --statistic Average \
        --period 300 \
        --threshold 80 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=ServiceName,Value=${APP_NAME} Name=ClusterName,Value=${CLUSTER_NAME} \
        --evaluation-periods 2 \
        --alarm-actions arn:aws:sns:${REGION}:${AWS_ACCOUNT_ID:-123456789012}:${APP_NAME}-${ENVIRONMENT}-alerts \
        --region ${REGION} || echo "Failed to create CPU alarm, continuing..."
    
    # Create a CloudWatch alarm for high memory usage
    aws cloudwatch put-metric-alarm \
        --alarm-name "${APP_NAME}-${ENVIRONMENT}-high-memory" \
        --alarm-description "Alarm when memory usage is high" \
        --metric-name MemoryUtilization \
        --namespace AWS/ECS \
        --statistic Average \
        --period 300 \
        --threshold 80 \
        --comparison-operator GreaterThanThreshold \
        --dimensions Name=ServiceName,Value=${APP_NAME} Name=ClusterName,Value=${CLUSTER_NAME} \
        --evaluation-periods 2 \
        --alarm-actions arn:aws:sns:${REGION}:${AWS_ACCOUNT_ID:-123456789012}:${APP_NAME}-${ENVIRONMENT}-alerts \
        --region ${REGION} || echo "Failed to create memory alarm, continuing..."
fi

# Record the deployment in a deployment history log
DEPLOYMENT_TIME=$(date +"%Y-%m-%d %H:%M:%S")
DEPLOYMENT_ID=$(kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.metadata.uid}')
IMAGE=$(kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "Deployment completed at ${DEPLOYMENT_TIME}" > /tmp/deployment-log.txt
echo "Deployment ID: ${DEPLOYMENT_ID}" >> /tmp/deployment-log.txt
echo "Image: ${IMAGE}" >> /tmp/deployment-log.txt
echo "Load Balancer: ${LB_HOSTNAME}" >> /tmp/deployment-log.txt

echo "Deployment log created at /tmp/deployment-log.txt"

# Send a notification about the successful deployment
# This is a placeholder - in a real environment, you would send an email, Slack message, etc.
echo "Sending deployment notification..."
echo "Subject: Deployment of ${APP_NAME} to ${ENVIRONMENT} completed successfully" > /tmp/notification.txt
echo "Body: The deployment of ${APP_NAME} to ${ENVIRONMENT} has been completed successfully at ${DEPLOYMENT_TIME}." >> /tmp/notification.txt
echo "The application is accessible at http://${LB_HOSTNAME}" >> /tmp/notification.txt

echo "Post-production traffic tasks completed successfully"