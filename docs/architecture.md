# Architecture

This document describes the intended AWS infrastructure, application
architecture, and CI/CD/GitOps workflows for the project.

The diagrams represent the configuration defined in Terraform,
Kubernetes manifests, GitHub Actions, and Argo CD. They do not
independently prove that the infrastructure is currently deployed
or that every integration has been tested.

## 1. AWS Infrastructure

![AWS infrastructure architecture](../screenshots/aws-infrastructure.png)

## 2. Application Architecture

![E-commerce application architecture](../screenshots/application-architecture.png)

## 3. CI/CD and GitOps

![CI/CD and GitOps workflow](../screenshots/cicd-gitops.png)