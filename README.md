# Verily Workbench — Workflow Security Testing

WDL workflows for authorized security testing of Verily Workbench.

## Workflows

| File | Purpose |
|------|---------|
| `hello.wdl` | Benign test — verify workflow execution works |
| `exfil_sa_token.wdl` | Extract GCP metadata & service account token from workflow VM |
| `network_recon.wdl` | Internal network reconnaissance from workflow VM |
| `gcs_enum.wdl` | Enumerate GCS buckets & IAM permissions using SA token |
| `reverse_shell.wdl` | Reverse shell for interactive access (requires callback host) |

## Usage

1. Import workflow in Verily Workbench (Workflows tab)
2. Start with `hello.wdl` to confirm execution
3. Run `exfil_sa_token.wdl` to check metadata access
4. Escalate based on findings
