#!/usr/bin/env sh
set -eu

CONFIGMAP_NAME="${CONFIGMAP_NAME:-external-dns-dynamic-ip}"
CONFIGMAP_KEY="${CONFIGMAP_KEY:-ip}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-external-dns}"
HANDLERS="${HANDLERS:-cloudflare_tls opendns_tls cloudflare opendns ipinfo}"
DEBUG="${DEBUG:-false}"

if [[ "$DEBUG" = "true" ]]; then
  set -x
fi

_get_ip_cloudflare_tls() (
  ip="$(doggo --short --type=TXT --class=CH @tls://1.1.1.1 whoami.cloudflare)"
  echo "${ip//\"/}"
)

_get_ip_cloudflare() (
  ip="$(doggo --short --type=TXT --class=CH @1.1.1.1 whoami.cloudflare)"
  echo "${ip//\"/}"
)

_get_ip_opendns_tls() (
  doggo --short @tls://dns.opendns.com myip.opendns.com
)

_get_ip_opendns() (
  doggo --short @resolver1.opendns.com myip.opendns.com
)

_get_ip_ipinfo() (
  wget -O- -q https://ipinfo.io/ip
)

_get_configmap_ip() (
  kubectl get configmap "$CONFIGMAP_NAME" --output=jsonpath='{.data.ip}' || true
)

for handler in $HANDLERS; do
    if ip="$("_get_ip_$handler")"; then
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
    --from-literal="$CONFIGMAP_KEY=$ip" \
    | kubectl apply --server-side --force-conflicts --filename=-

  if [[ -n "${DEPLOYMENT_NAME:-}" ]]; then
    echo "Restarting deployment/$DEPLOYMENT_NAME"
    kubectl rollout restart deployment "$DEPLOYMENT_NAME"
  fi
else
  echo "IP unchanged: $ip"
fi
