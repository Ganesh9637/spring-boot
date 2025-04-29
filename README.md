# Spring Boot on Amazon EKS

This repository contains the necessary configuration to deploy a Spring Boot application on Amazon EKS using an AWS-native CI/CD pipeline.

## Architecture

The solution includes:

1. **Amazon EKS Cluster** - Managed Kubernetes service for running containerized applications
2. **AWS Load Balancer Controller** - For managing Elastic Load Balancers for Kubernetes services
3. **CI/CD Pipeline** - Using AWS CodePipeline, CodeBuild, and Amazon ECR
4. **Infrastructure as Code** - Using AWS CloudFormation templates

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed
- Helm installed
- GitHub repository with this code

## Deployment Instructions

### 1. Deploy the EKS Cluster

```bash
aws cloudformation create-stack \
  --stack-name spring-boot-eks \
  --template-body file://infrastructure/eks-cluster.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=ClusterName,ParameterValue=spring-boot-eks-cluster
```

Wait for the EKS cluster to be created (this may take 15-20 minutes).

### 2. Configure kubectl

```bash
aws eks update-kubeconfig --name spring-boot-eks-cluster --region us-east-1
```

### 3. Install AWS Load Balancer Controller

```bash
chmod +x scripts/install-lb-controller.sh
./scripts/install-lb-controller.sh spring-boot-eks-cluster us-east-1
```

### 4. Deploy the CI/CD Pipeline

```bash
aws cloudformation create-stack \
  --stack-name spring-boot-cicd \
  --template-body file://infrastructure/cicd-pipeline.yaml \
  --capabilities CAPABILITY_IAM \
  --parameters \
    ParameterKey=GitHubOwner,ParameterValue=<your-github-username> \
    ParameterKey=GitHubRepo,ParameterValue=<your-github-repo> \
    ParameterKey=GitHubBranch,ParameterValue=main \
    ParameterKey=GitHubToken,ParameterValue=<your-github-token> \
    ParameterKey=EksClusterName,ParameterValue=spring-boot-eks-cluster
```

## CI/CD Pipeline Workflow

1. **Source Stage**: Fetches the code from GitHub when changes are pushed
2. **Test Stage**: Runs unit and integration tests
3. **Build Stage**: Builds the application and Docker image, then pushes to Amazon ECR
4. **Deploy Stage**: Deploys the application to Amazon EKS

## Kubernetes Resources

- **Namespace**: `spring-boot`
- **Deployment**: Manages the Spring Boot application pods
- **Service**: Exposes the application using a Network Load Balancer

## Monitoring and Troubleshooting

- Access the application: The service URL will be available in the AWS Console under EC2 > Load Balancers
- View logs: `kubectl logs -f -l app=spring-boot-app -n spring-boot`
- Check deployment status: `kubectl get deployments -n spring-boot`
- Check service status: `kubectl get services -n spring-boot`

## Cleanup

To delete all resources:

```bash
# Delete the CI/CD pipeline
aws cloudformation delete-stack --stack-name spring-boot-cicd

# Delete the EKS cluster
aws cloudformation delete-stack --stack-name spring-boot-eks
```

## Security Considerations

- The EKS cluster uses private subnets for worker nodes
- IAM roles follow the principle of least privilege
- Network security groups restrict access to the necessary ports only
- Kubernetes RBAC is enabled by default