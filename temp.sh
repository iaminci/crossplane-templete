#!/bin/bash

echo "Creating GCP project"
gcloud iam service-accounts create crossplane-sa \
    --project=${GCP_PROJECT}

echo "Enabling required APIs"
gcloud projects add-iam-policy-binding ${GCP_PROJECT} \
    --member="serviceAccount:crossplane-sa@${GCP_PROJECT}.iam.gserviceaccount.com" \
    --role="roles/owner"

echo "Creating service account key"
gcloud iam service-accounts keys create creds.json \
    --iam-account=crossplane-sa@crossplane-450710.iam.gserviceaccount.com