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

### 3.1. Install Argo CD

#### Step 1: Create Namespace
```bash
# Create a dedicated namespace for Argo CD
kubectl create namespace argocd

# Verify namespace creation
kubectl get namespaces | grep argocd
```

#### Step 2: Install Argo CD Components
```bash
# Install Argo CD using the official installation manifest
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be ready (this may take a few minutes)
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

# Verify installation
kubectl get pods -n argocd
```

Expected output:
```
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          2m
argocd-applicationset-controller-7c7b6c5c4d-xyz     1/1     Running   0          2m
argocd-dex-server-6fd8b59f5b-abc                    1/1     Running   0          2m
argocd-notifications-controller-5557f7bb5b-def      1/1     Running   0          2m
argocd-redis-ha-haproxy-7c548c5bf7-ghi              1/1     Running   0          2m
argocd-redis-ha-server-0                            1/1     Running   0          2m
argocd-repo-server-7f5c6b8c9d-jkl                   1/1     Running   0          2m
argocd-server-6b7d8f9c5d-mno                        1/1     Running   0          2m
```

### 3.2. Access Argo CD

#### Option 1: Port Forward (Recommended for Local Development)
```bash
# Forward port 8080 to access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access Argo CD at https://localhost:8080
# Note: You'll get a certificate warning - this is normal for local development
```

#### Option 2: LoadBalancer (For Cloud Environments)
```bash
# Change the service type to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get the external IP (may take a few minutes)
kubectl get svc argocd-server -n argocd

# Wait for external IP to be assigned
kubectl get svc argocd-server -n argocd -w
```

#### Option 3: NodePort (For On-Premise Clusters)
```bash
# Change the service type to NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# Get the NodePort
kubectl get svc argocd-server -n argocd
```

### 3.3. Get Initial Admin Credentials

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Store the password in a variable for convenience
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Admin password: $ARGOCD_PASSWORD"
```

### 3.4. Install Argo CD CLI

#### macOS
```bash
# Using Homebrew
brew install argocd

# Or download directly
curl -sSL -o argocd-darwin-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
sudo install -m 555 argocd-darwin-amd64 /usr/local/bin/argocd
rm argocd-darwin-amd64
```

#### Linux
```bash
# Download and install
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

#### Windows
```powershell
# Using Chocolatey
choco install argocd-cli

# Or download from GitHub releases
# https://github.com/argoproj/argo-cd/releases/latest
```

#### Verify CLI Installation
```bash
argocd version --client
```

### 3.5. Login to Argo CD

#### Using CLI (Port Forward)
```bash
# Login using port forward
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure

# Or login interactively
argocd login localhost:8080 --insecure
```

#### Using CLI (External IP)
```bash
# Get external IP first
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Login to Argo CD
argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PASSWORD --insecure --grpc-web
```

#### Using Web UI
1. Open browser and navigate to Argo CD URL
2. Username: `admin`
3. Password: Use the password retrieved in step 3.3
4. Click "Sign In"

## 4. Core Concepts

Understanding these core concepts is essential for working with Argo CD effectively.

### 4.1. Applications

An Application in Argo CD represents a deployed application instance in a target environment. It defines:
- **Source**: Git repository, path, and target revision
- **Destination**: Target cluster and namespace
- **Sync Policy**: How the application should be synchronized

#### Application Manifest Example
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

### 4.2. Projects

Projects provide logical grouping of applications and enable:
- **Multi-tenancy**: Restrict access to applications
- **Security**: Define allowed repositories and clusters
- **Resource Management**: Set resource quotas and limits

#### Project Manifest Example
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: my-project
  namespace: argocd
spec:
  description: "My Application Project"
  sourceRepos:
  - 'https://github.com/myorg/myrepo.git'
  destinations:
  - namespace: 'my-app-*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  namespaceResourceWhitelist:
  - group: 'apps'
    kind: Deployment
  - group: ''
    kind: Service
```

### 4.3. Sync Status and Health

#### Sync Status
- **Synced**: Live state matches Git state
- **OutOfSync**: Live state differs from Git state
- **Unknown**: Unable to determine sync status

#### Health Status
- **Healthy**: All resources are healthy
- **Progressing**: Resources are being created/updated
- **Degraded**: Some resources are unhealthy
- **Missing**: Resources are missing
- **Unknown**: Unable to determine health

### 4.4. Application Health Checks

Argo CD performs health checks on various Kubernetes resources:

```bash
# Check application health and sync status
argocd app get guestbook

# Get detailed application information
argocd app get guestbook -o yaml

# Watch application status in real-time
argocd app get guestbook --watch
```

## 5. Application Management

### 5.1. Creating Your First Application

#### Method 1: Using CLI
```bash
# Create a simple guestbook application
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Verify application creation
argocd app list
```

#### Method 2: Using YAML Manifest
```bash
# Create application manifest
cat <<EOF > guestbook-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# Apply the application
kubectl apply -f guestbook-app.yaml

# Verify creation
argocd app list
```

### 5.2. Synchronization

#### Manual Sync
```bash
# Sync application manually
argocd app sync guestbook

# Sync with prune (removes resources not in Git)
argocd app sync guestbook --prune

# Dry run sync (preview changes)
argocd app sync guestbook --dry-run

# Force sync (ignore sync hooks)
argocd app sync guestbook --force
```

#### Automated Sync
```bash
# Enable automated sync
argocd app set guestbook --sync-policy automated

# Enable auto-prune (removes orphaned resources)
argocd app set guestbook --auto-prune

# Enable self-heal (corrects manual changes)
argocd app set guestbook --self-heal

# Disable automated sync
argocd app unset guestbook --sync-policy
```

### 5.3. Application History and Rollbacks

#### View History
```bash
# Show application deployment history
argocd app history guestbook

# Show specific revision details
argocd app history guestbook --revision 5
```

#### Rollback Operations
```bash
# Rollback to previous revision
argocd app rollback guestbook

# Rollback to specific revision
argocd app rollback guestbook 3

# Rollback with confirmation
argocd app rollback guestbook 3 --timeout 300
```

### 5.4. Application Operations

#### Get Application Information
```bash
# List all applications
argocd app list

# Get application details
argocd app get guestbook

# Get application manifest
argocd app manifests guestbook

# Get application diff
argocd app diff guestbook
```

#### Update Applications
```bash
# Set application parameters
argocd app set guestbook --parameter key=value

# Set Helm values
argocd app set guestbook --values values.yaml

# Change target revision
argocd app set guestbook --revision v2.0.0

# Change destination namespace
argocd app set guestbook --dest-namespace production
```

#### Delete Applications
```bash
# Delete application (keeps resources)
argocd app delete guestbook

# Delete application and all resources
argocd app delete guestbook --cascade

# Force delete application
argocd app delete guestbook --force
```

## 6. Advanced Features

### 6.1. Sync Policies

#### Sync Options
```yaml
syncPolicy:
  syncOptions:
  - CreateNamespace=true      # Create namespace if it doesn't exist
  - PrunePropagationPolicy=foreground  # How to delete resources
  - PruneLast=true           # Prune resources after new ones are created
  - Validate=false           # Skip kubectl validation
  - ApplyOutOfSyncOnly=true  # Only sync out-of-sync resources
```

#### Sync Hooks
```yaml
# Pre-sync hook example
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-sync-job
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      containers:
      - name: migration
        image: migrate/migrate
        command: ["migrate", "up"]
      restartPolicy: Never
```

### 6.2. Multi-Source Applications

Support for applications that combine multiple sources:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: multi-source-app
spec:
  sources:
  - repoURL: https://github.com/myorg/app-config
    path: config
    targetRevision: HEAD
  - repoURL: https://github.com/myorg/app-charts
    path: charts/myapp
    targetRevision: HEAD
    helm:
      valueFiles:
      - $values/config/values.yaml
  - repoURL: https://github.com/myorg/app-values
    targetRevision: HEAD
    ref: values
```

### 6.3. App of Apps Pattern

Deploy multiple applications using a parent application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/app-of-apps
    targetRevision: HEAD
    path: applications
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Application definitions in the repository:
```yaml
# applications/app1.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app1
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/app1
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: app1
```

### 6.4. ApplicationSets

Generate applications dynamically:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-appset
  namespace: argocd
spec:
  generators:
  - clusters: {}
  template:
    metadata:
      name: '{{name}}-guestbook'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: '{{server}}'
        namespace: guestbook
```

### 6.5. Repository Management

#### Add Private Repository (SSH)
```bash
# Add SSH repository
argocd repo add git@github.com:myorg/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Add SSH repository with passphrase
argocd repo add git@github.com:myorg/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa \
  --ssh-private-key-passphrase
```

#### Add Private Repository (HTTPS)
```bash
# Add HTTPS repository with token
argocd repo add https://github.com/myorg/private-repo.git \
  --username myuser \
  --password ghp_xxxxxxxxxxxx

# Add HTTPS repository with app password
argocd repo add https://bitbucket.org/myorg/private-repo.git \
  --username myuser \
  --password app-password
```

#### List and Remove Repositories
```bash
# List repositories
argocd repo list

# Remove repository
argocd repo rm https://github.com/myorg/private-repo.git
```

### 6.6. Cluster Management

#### Add External Clusters
```bash
# Add cluster using current kubectl context
argocd cluster add my-cluster-context

# Add cluster with specific name
argocd cluster add my-cluster-context --name production

# List clusters
argocd cluster list

# Get cluster information
argocd cluster get https://kubernetes.default.svc
```

### 6.7. User Management and RBAC

#### Create Local Users
```yaml
# argocd-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  accounts.alice: apiKey, login
  accounts.bob: apiKey
```

#### Configure RBAC
```yaml
# argocd-rbac-cm ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    g, alice, role:admin
    g, bob, role:readonly
```

## 7. Best Practices

### 7.1. Repository Structure

#### Recommended Structure
```
my-app-repo/
├── environments/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── production/
│       ├── kustomization.yaml
│       └── values.yaml
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── helm-chart/
    ├── Chart.yaml
    ├── values.yaml
    └── templates/
```

### 7.2. Application Naming

```bash
# Use descriptive names with environment
argocd app create myapp-dev \
  --repo https://github.com/myorg/myapp.git \
  --path environments/dev \
  --dest-namespace myapp-dev

argocd app create myapp-prod \
  --repo https://github.com/myorg/myapp.git \
  --path environments/production \
  --dest-namespace myapp-prod
```

### 7.3. Sync Policies

#### For Development
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
  - CreateNamespace=true
```

#### For Production
```yaml
syncPolicy:
  # Manual sync for production
  syncOptions:
  - CreateNamespace=true
  - PrunePropagationPolicy=foreground
```

### 7.4. Health Checks

#### Custom Health Checks
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.health.MyCustomResource: |
    hs = {}
    if obj.status ~= nil then
      if obj.status.phase == "Running" then
        hs.status = "Healthy"
        hs.message = "MyCustomResource is running"
        return hs
      end
    end
    hs.status = "Progressing"
    hs.message = "Waiting for MyCustomResource"
    return hs
```

## 8. Troubleshooting

### 8.1. Common Issues

#### Application Stuck in Progressing
```bash
# Check application status
argocd app get myapp

# Check Kubernetes events
kubectl get events -n myapp-namespace --sort-by='.lastTimestamp'

# Check pod logs
kubectl logs -n myapp-namespace deployment/myapp

# Force refresh application
argocd app get myapp --refresh
```

#### Sync Failures
```bash
# Check sync result
argocd app get myapp -o yaml | grep -A 10 operationState

# Get sync logs
argocd app logs myapp

# Manual sync with detailed output
argocd app sync myapp --dry-run --detailed
```

#### Permission Issues
```bash
# Check RBAC policies
kubectl get configmap argocd-rbac-cm -n argocd -o yaml

# Check user accounts
kubectl get configmap argocd-cm -n argocd -o yaml

# Test user permissions
argocd account can-i sync applications '*'
```

### 8.2. Debugging Commands

```bash
# Application information
argocd app get myapp --show-params
argocd app get myapp --show-operation

# Repository connectivity
argocd repo get https://github.com/myorg/myrepo.git

# Cluster connectivity
argocd cluster get https://kubernetes.default.svc

# Server logs
kubectl logs -n argocd deployment/argocd-server

# Application controller logs
kubectl logs -n argocd deployment/argocd-application-controller
```

### 8.3. Performance Tuning

#### Application Controller Tuning
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  application.instanceLabelKey: argocd.argoproj.io/instance
  server.insecure: "true"
  controller.status.processors: "20"
  controller.operation.processors: "10"
  controller.self.heal.timeout.seconds: "5"
  controller.repo.server.timeout.seconds: "60"
```

## 9. Monitoring and Observability

### 9.1. Metrics

Argo CD exposes metrics in Prometheus format:

```bash
# Access metrics endpoint
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082
curl http://localhost:8082/metrics
```

### 9.2. Notifications

Configure notifications for application events:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: xoxb-xxxx
  template.app-deployed: |
    email:
      subject: New version of an application {{.app.metadata.name}} is up and running.
    message: |
      Application {{.app.metadata.name}} is now running new version.
  trigger.on-deployed: |
    - description: Application is synced and healthy
      send:
      - app-deployed
      when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
```

## 10. Backup and Disaster Recovery

### 10.1. Backup Argo CD

```bash
# Backup applications
argocd app list -o yaml > argocd-apps-backup.yaml

# Backup projects
kubectl get appproject -n argocd -o yaml > argocd-projects-backup.yaml

# Backup repositories
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository -o yaml > argocd-repos-backup.yaml

# Backup clusters
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster -o yaml > argocd-clusters-backup.yaml
```

### 10.2. Restore Argo CD

```bash
# Restore applications
kubectl apply -f argocd-apps-backup.yaml

# Restore projects
kubectl apply -f argocd-projects-backup.yaml

# Restore repositories
kubectl apply -f argocd-repos-backup.yaml

# Restore clusters
kubectl apply -f argocd-clusters-backup.yaml
```

## Conclusion

This guide covered the essential aspects of Argo CD from basic installation to advanced features. Key takeaways:

1. **Start Simple**: Begin with basic applications and manual sync
2. **Understand GitOps**: Git is the source of truth
3. **Use Projects**: Organize applications logically
4. **Implement RBAC**: Secure access appropriately
5. **Monitor Health**: Keep track of application status
6. **Plan for Scale**: Use ApplicationSets and App of Apps pattern
7. **Follow Best Practices**: Structure repositories properly
8. **Test Thoroughly**: Use dry-run and staging environments

For more information, visit the [official Argo CD documentation](https://argo-cd.readthedocs.io/).
