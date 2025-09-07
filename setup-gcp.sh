#!/bin/bash

# GCP Project and Repository Configuration
PROJECT_ID="calm-vine-465617-j3"
LOCATION="us-central1"
REPOSITORY="argocd-repo"

echo "🔍 Checking GCP Artifact Registry setup..."

# Check if repository exists
echo "Checking if repository '$REPOSITORY' exists in location '$LOCATION'..."
if gcloud artifacts repositories describe $REPOSITORY --location=$LOCATION --project=$PROJECT_ID &>/dev/null; then
    echo "✅ Repository '$REPOSITORY' exists"
else
    echo "❌ Repository '$REPOSITORY' does not exist"
    echo "Creating repository..."
    
    gcloud artifacts repositories create $REPOSITORY \
        --repository-format=docker \
        --location=$LOCATION \
        --description="Docker repository for ArgoCD demo" \
        --project=$PROJECT_ID
    
    if [ $? -eq 0 ]; then
        echo "✅ Repository created successfully"
    else
        echo "❌ Failed to create repository"
        exit 1
    fi
fi

# Check service account permissions
echo "Checking service account permissions..."
SERVICE_ACCOUNT="argocd-builder@$PROJECT_ID.iam.gserviceaccount.com"

# Check if service account has Artifact Registry Writer role
echo "Checking if service account has required permissions..."
gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format='table(bindings.role)' --filter="bindings.members:$SERVICE_ACCOUNT" | grep -q "roles/artifactregistry.writer"

if [ $? -eq 0 ]; then
    echo "✅ Service account has Artifact Registry Writer permissions"
else
    echo "❌ Service account missing Artifact Registry Writer permissions"
    echo "Adding permissions..."
    
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SERVICE_ACCOUNT" \
        --role="roles/artifactregistry.writer"
    
    if [ $? -eq 0 ]; then
        echo "✅ Permissions added successfully"
    else
        echo "❌ Failed to add permissions"
        exit 1
    fi
fi

echo "🎉 Setup verification complete!"
echo ""
echo "Next steps:"
echo "1. Add the service account key to GitHub Secrets as 'GCP_SA_KEY'"
echo "2. Push your changes to trigger the workflow"
echo ""
echo "Repository URL: $LOCATION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY"
