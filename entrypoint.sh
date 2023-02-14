#!/bin/sh
set -eu

_get_ip() (
  set -e
  ip="$(dig +short txt ch whoami.cloudflare @1.1.1.1)"
  echo "${ip//\"/}"
)

_get_configmap_ip() (
  kubectl get configmap "$CONFIGMAP_NAME" -o jsonpath='{.data.ip}' || true
)

ip="$(_get_ip)"
configmap_ip="$(_get_configmap_ip)"

if [[ -n "$ip" && "$ip" != "$configmap_ip" ]]; then
  echo "Updating IP to $ip" >&2

  kubectl create configmap "$CONFIGMAP_NAME" \
    --dry-run=client --output=yaml \
    --from-literal=ip="$ip" \
    | kubectl apply --server-side --filename=-

  kubectl rollout restart deployment "$DEPLOYMENT_NAME"
fi
