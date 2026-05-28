version 1.0

workflow HelloWorld {
    call SayHello
}

task SayHello {
    command <<<
        echo "Hello from Verily Workbench workflow!"
        echo "Date: $(date)"
        echo "Hostname: $(hostname)"
        echo "User: $(whoami)"
        echo "PWD: $(pwd)"
        ls -la
    >>>

    output {
        File result = stdout()
    }

    runtime {
        docker: "ubuntu:22.04"
    }
}
