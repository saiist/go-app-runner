#!/bin/bash
set -e

REPO_URL=$1
IMAGE_TAG=$2
REGION=$3

echo "Logging into ECR repository: ${REPO_URL}"
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${REPO_URL}

echo "Building Docker image: ${REPO_URL}:${IMAGE_TAG}"
docker build -t ${REPO_URL}:${IMAGE_TAG} .

echo "Pushing Docker image to ECR"
docker push ${REPO_URL}:${IMAGE_TAG}

echo "Docker image pushed successfully"