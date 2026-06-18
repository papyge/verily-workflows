version 1.0

workflow CrossTenantTest {
    call CheckAccess
}

task CheckAccess {
    command <<<
        echo "=== CROSS-TENANT TEST ==="
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "Hostname: $(hostname)"
        curl --version || echo "no curl"
        python3 --version || echo "no python3"
        echo "=== DONE ==="
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}
