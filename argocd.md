# Complete Argo CD Learning Guide

This comprehensive guide provides everything you need to know about Argo CD, a declarative GitOps continuous delivery tool for Kubernetes. This guide is designed for beginners and covers all essential concepts with practical examples.

## Table of Contents
1. [What is Argo CD?](#1-what-is-argo-cd)
2. [Prerequisites](#2-prerequisites)
3. [Initial Setup & Installation](#3-initial-setup--installation)
4. [Core Concepts](#4-core-concepts)
5. [Application Management](#5-application-management)
6. [Advanced Features](#6-advanced-features)
7. [Best Practices](#7-best-practices)
8. [Troubleshooting](#8-troubleshooting)

## 1. What is Argo CD?

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes that:
- Follows the GitOps pattern where Git repositories are the source of truth
- Automatically deploys applications to Kubernetes clusters
- Provides a web UI and CLI for managing applications
- Monitors Git repositories for changes and syncs them to clusters
- Supports rollbacks, health monitoring, and automated healing

### GitOps Principles
1. **Declarative**: The entire system is described declaratively
2. **Versioned and Immutable**: The canonical desired system state is versioned in Git
3. **Pulled Automatically**: Software agents automatically pull the desired state declarations from the source
4. **Continuously Reconciled**: Software agents continuously observe actual system state and attempt to apply the desired state

## 2. Prerequisites

Before starting with Argo CD, ensure you have:
- A running Kubernetes cluster (local or cloud-based)
- `kubectl` configured to access your cluster
- Basic understanding of Kubernetes concepts (Pods, Services, Deployments)
- Git repository with Kubernetes manifests
- Docker (if building custom applications)

### Verify Prerequisites
```bash
# Check Kubernetes cluster access
kubectl cluster-info

# Check kubectl version
kubectl version --client

# Check available nodes
kubectl get nodes
```

## 3. Initial Setup & Installation

This section covers the complete installation and setup process.

### 1.1. Installation

1. Create the Argo CD namespace:
   ```bash
   kubectl create namespace argocd
   ```

2. Apply the Argo CD installation manifests:
   ```bash
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

### 1.2. Expose Argo CD Server

1. Change the `argocd-server` service type to `LoadBalancer`:
   ```bash
   kubectl patch svc argocd-server -n argocd -p '''{"spec": {"type": "LoadBalancer"}}'''
   ```

2. Get the external IP address of the Argo CD server:
   ```bash
   kubectl get svc argocd-server -n argocd -o jsonpath='''{'.status.loadBalancer.ingress[0].ip'}'''
   ```
   (IP: 35.184.236.245)

### 1.3. Login to Argo CD

1. Get the initial admin password:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```
   2. Login to the Argo CD CLI:
   ```bash
   argocd login 35.184.236.245 --insecure --username admin --password $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) --grpc-web
   ```

### 1.4. Deploy Application

1. Create the `guestbook` application:
   ```bash
   argocd app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
   ```

2. Sync the `guestbook` application:
   ```bash
   argocd app sync guestbook
   ```

3. Verify the deployment:
   ```bash
   kubectl get deployment guestbook-ui -n default
   ```

### 1.5. Access the Application

1. Expose the `guestbook-ui` service:
   ```bash
   kubectl patch svc guestbook-ui -n default -p '''{"spec": {"type": "LoadBalancer"}}'''
   ```

2. Get the external IP address of the `guestbook-ui` service:
   ```bash
   kubectl get svc guestbook-ui -n default -o jsonpath='''{'.status.loadBalancer.ingress[0].ip'}'''
   ```
   (IP: 34.46.6.170)

You can now access the guestbook application by navigating to http://34.46.6.170 in your web browser.

## 2. Core Argo CD Concepts

This section delves into the fundamental concepts of Argo CD.

### 2.1. Application Health and Sync Status

Argo CD provides detailed information about the health and sync status of your applications.

*   **Health Status:** Indicates the health of the deployed resources. Common statuses include `Healthy`, `Progressing`, `Degraded`, `Missing`, and `Unknown`.
*   **Sync Status:** Shows whether the live state of the application in the cluster matches the desired state in the Git repository. Common statuses include `Synced`, `OutOfSync`.

You can check the status of an application using the following command:

```bash
argocd app get guestbook
```

### 2.2. Sync Policies

Argo CD offers different sync policies to control how changes are deployed.

*   **Manual Sync (Default):** Changes in the Git repository are not automatically applied to the cluster. You need to manually sync the application.

    To manually sync an application:
    ```bash
    argocd app sync guestbook
    ```

*   **Automated Sync:** Argo CD automatically detects changes in the Git repository and applies them to the cluster.

    To enable automated sync:
    ```bash
    argocd app set guestbook --sync-policy automated
    ```

### 2.3. Self-Heal

With automated sync, you can also enable self-healing. If the live state of the application deviates from the desired state in Git (e.g., due to manual changes in the cluster), Argo CD will automatically correct the deviation.

To enable self-heal:
```bash
argocd app set guestbook --auto-prune --self-heal
```

### 2.4. Rollbacks

Argo CD allows you to easily roll back to a previous version of your application. You can see the deployment history and choose a specific revision to roll back to.

To see the history of an application:
```bash
argocd app history guestbook
```

To roll back to a specific revision (e.g., revision 1):
```bash
argocd app rollback guestbook 1
```

### 2.5. Prune Resources

The `prune` option, when used with `argocd app sync`, removes resources from the cluster that are no longer defined in the Git repository.

To sync with pruning:
```bash
argocd app sync guestbook --prune
```

When using automated sync with self-heal, you can also enable auto-pruning:

```bash
argocd app set guestbook --auto-prune --self-heal
```

## 3. Advanced Argo CD Concepts

### 3.1. App of Apps Pattern

The App of Apps pattern is a powerful way to manage multiple applications with Argo CD. You create a single "parent" application that is responsible for deploying and managing multiple "child" applications.

This is typically done by having a Git repository that contains the Argo CD application manifests for all of your applications. The parent application points to this repository.

### 3.2. Projects

Argo CD Projects provide a way to group applications and restrict access to them. You can define which users and groups have access to which projects, and what actions they can perform.

This is useful for multi-tenant environments where you want to isolate different teams or applications from each other.

### 3.3. Notifications

Argo CD can be configured to send notifications about application events to various services like Slack, email, or webhook endpoints.

This allows you to stay informed about the status of your deployments and quickly react to any issues.