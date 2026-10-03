#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
: "${KUBECONFIG:?Select the dedicated management cluster kubeconfig}"
: "${EXPECTED_CONTEXT:?Set the exact reviewed kubectl context}"
: "${RANCHER_HOSTNAME:?Use a DNS name resolving to management ingress}"
[[ ${LAB_BOOTSTRAP_ACK:-} == yes ]] || { echo 'Set LAB_BOOTSTRAP_ACK=yes after context and values review.' >&2; exit 1; }
[[ $(kubectl config current-context) == "$EXPECTED_CONTEXT" ]] || { echo 'Kubernetes context mismatch.' >&2; exit 1; }
[[ $(helm version --template '{{.Version}}') == v3.20.* ]] || { echo 'Use a patched Helm 3.20.x release compatible with Kubernetes 1.35.' >&2; exit 1; }
[[ $RANCHER_HOSTNAME =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+$ ]] || { echo 'Invalid DNS hostname.' >&2; exit 1; }
version=$(kubectl version -o json | python3 -c 'import json,sys; print(json.load(sys.stdin)["serverVersion"]["gitVersion"])')
[[ $version == v1.35.9+k3s1 ]] || { echo 'Management Kubernetes version differs from the reviewed pin.' >&2; exit 1; }
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager --version v1.20.4 \
  --namespace cert-manager --create-namespace --set crds.enabled=true --wait --timeout 10m
# No static/bootstrap password in argv, env, values, or repository: Rancher generates it.
helm upgrade --install rancher rancher-stable/rancher --version 2.14.3 \
  --namespace cattle-system --create-namespace --values manifests/rancher-values.yaml \
  --set-string "hostname=$RANCHER_HOSTNAME" --wait --timeout 15m
kubectl -n cattle-system rollout status deployment/rancher --timeout=300s
printf '%s\n' 'Rancher installed. Retrieve the generated bootstrap secret only in your private terminal.'
