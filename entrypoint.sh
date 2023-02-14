#!/bin/sh
set -eu

CONFIGMAP_NAME="${CONFIGMAP_NAME:-external-dns-dynamic-ip}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-external-dns}"

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

if [[ -z "$ip" ]]; then
  echo "Failed to get public IP: Empty response"
  exit 1
elif [[ "$ip" != "$configmap_ip" ]]; then
  echo "Patching configmap/$CONFIGMAP_NAME with new IP: $configmap_ip to $ip" >&2

  kubectl create configmap "$CONFIGMAP_NAME" \
    --dry-run=client --output=yaml \
    --from-literal=ip="$ip" \
    | kubectl apply --server-side --filename=-

  kubectl rollout restart deployment "$DEPLOYMENT_NAME"
else
  echo "IP unchanged: $ip"
fi
