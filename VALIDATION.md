# Local validation record — 2026-10-03

Passed: `terraform init -backend=false`, `terraform fmt -check`, `terraform validate`, Ansible syntax check against sanitized bare-metal inventory, and `bash -n` for all scripts. Provider lock file is included. Documentation addresses and fake public-key placeholders are intentional.

Not executed: Terraform plan against a real endpoint, apply/destroy, SSH bootstrap, Kubernetes API operations, secret creation or publication. Runtime behavior needs an isolated owner-reviewed lab test. No estate configuration or credentials were copied.

Official Rancher 2.14.3 and cert-manager v1.20.4 charts rendered successfully for Kubernetes 1.35.9 with a checksum-verified temporary **Helm v3.20.2** executable. Resource limits and Traefik ingress class appeared in the rendered Rancher deployment. No cluster was contacted. Rancher 2.14.4 was initially selected from its support-matrix page but its chart was absent from both official indexes; corrected to available compatible 2.14.3. Temporary executable and generated outputs were discarded.

## Manual private CI additions (2026-10-03)

Local checks passed: actionlint (custom homelab label declared), ShellCheck, every Bash script syntax, GitHub/GitLab YAML parsing, and helper fail-closed behavior without private/enabled deployment flags. Terraform fmt, backend-disabled init, validate and Ansible syntax checks passed. The first workflow lint flagged the intentional custom runner label; declaring that label corrected the diagnostic. The initial validation inventory filename was corrected to the existing bare-metal example before final checks. No Terraform plan/apply, SSH bootstrap, real CI deployment or Kubernetes API calls were performed. Runner prerequisites, secrets, TLS/host trust, persistent-state backup and actual first deployment remain unverified. Existing runtime diagnostic limitations above are unchanged.
