# Local validation record — 2026-10-03

Passed: `terraform init -backend=false`, `terraform fmt -check`, `terraform validate`, Ansible syntax check against sanitized bare-metal inventory, and `bash -n` for all scripts. Provider lock file is included. Documentation addresses and fake public-key placeholders are intentional.

Not executed: Terraform plan against a real endpoint, apply/destroy, SSH bootstrap, Kubernetes API operations, secret creation or publication. Runtime behavior needs an isolated owner-reviewed lab test. No estate configuration or credentials were copied.

Official Rancher 2.14.3 and cert-manager v1.20.4 chart rendering passed locally for Kubernetes 1.35.9; resource limits and Traefik ingress class appeared in the rendered deployment. The installed renderer was Helm 4.3.0, so this is a template/schema check, not evidence of the required Helm 3.20.x installation path. Rancher 2.14.4 was initially selected from its support-matrix page but its chart was absent from both official indexes; corrected to available compatible 2.14.3. Transient rendered files were removed.
