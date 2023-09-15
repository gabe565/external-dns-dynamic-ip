#!/bin/sh
set -eu

CONFIGMAP_NAME="${CONFIGMAP_NAME:-external-dns-dynamic-ip}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-external-dns}"
HANDLERS="${HANDLERS:-cloudflare opendns ipinfo}"

_get_ip_cloudflare() (
  ip="$(dig +short txt ch whoami.cloudflare @1.1.1.1)"
  echo "${ip//\"/}"
)

_get_ip_opendns() (
  dig +short myip.opendns.com @resolver1.opendns.com
)

_get_ip_ipinfo() (
  wget -O- -q https://ipinfo.io/ip
)

_get_configmap_ip() (
  kubectl get configmap "$CONFIGMAP_NAME" --output=jsonpath='{.data.ip}' || true
)

for handler in $HANDLERS; do
    ip="$("_get_ip_$handler" || true)"
    if [[ -n "$ip" ]]; then
        echo "Got IP from handler: $handler"
        break
    fi
    echo "Failed to get public IP from handler: $handler"
done
if [[ -z "$ip" ]]; then
  echo "All handlers failed"
  exit 1
fi

configmap_ip="$(_get_configmap_ip)"
if [[ "$ip" != "$configmap_ip" ]]; then
  echo "Patching configmap/$CONFIGMAP_NAME with new IP: $configmap_ip to $ip" >&2

  kubectl create configmap "$CONFIGMAP_NAME" \
    --dry-run=client --output=yaml \
    --from-literal=ip="$ip" \
    | kubectl apply --server-side --filename=-

  echo "Restarting deployment/$DEPLOYMENT_NAME"
  kubectl rollout restart deployment "$DEPLOYMENT_NAME"
else
  echo "IP unchanged: $ip"
fi
