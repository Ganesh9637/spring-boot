#!/bin/bash
set -e

echo "After allow test traffic script - running tests against the deployed application"

# Define variables
NAMESPACE="spring-boot"
DEPLOYMENT_NAME="spring-boot-app"
MAX_RETRY=5
RETRY_INTERVAL=10
TEST_ENDPOINT="/actuator/health"
HTTP_STATUS_OK=200

# Get the load balancer hostname
LB_HOSTNAME=$(kubectl get service ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$LB_HOSTNAME" ]; then
    echo "Error: Could not get load balancer hostname"
    exit 1
fi

echo "Load balancer hostname: $LB_HOSTNAME"

# Wait for DNS propagation
echo "Waiting for DNS propagation..."
sleep 30

# Function to test the endpoint
test_endpoint() {
    local endpoint=$1
    local expected_status=$2
    
    echo "Testing endpoint: $endpoint"
    
    # Use curl to test the endpoint
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${LB_HOSTNAME}${endpoint})
    
    if [ "$HTTP_STATUS" -eq "$expected_status" ]; then
        echo "Test passed: Endpoint $endpoint returned status $HTTP_STATUS"
        return 0
    else
        echo "Test failed: Endpoint $endpoint returned status $HTTP_STATUS, expected $expected_status"
        return 1
    fi
}

# Test the health endpoint with retries
echo "Testing health endpoint..."
for i in $(seq 1 $MAX_RETRY); do
    if test_endpoint "$TEST_ENDPOINT" "$HTTP_STATUS_OK"; then
        break
    fi
    
    if [ $i -eq $MAX_RETRY ]; then
        echo "Health check failed after $MAX_RETRY attempts"
        exit 1
    fi
    
    echo "Retrying in $RETRY_INTERVAL seconds... (Attempt $i/$MAX_RETRY)"
    sleep $RETRY_INTERVAL
done

# Additional tests can be added here
# For example, testing specific API endpoints, performance tests, etc.

echo "All tests passed successfully"