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

_parse_doggo_response() (
  response="$(cat)"
  error="$(echo "$response" | jq -r '.error // ""')"
  if [[ -n "$error" ]]; then
    echo "$error" >&2
    return 1
  fi
  echo "$response" | jq -re ".responses[0].answers[0].address | ${1:-.}"
)

_get_ip_cloudflare_tls() (
  doggo --json --type=TXT --class=CH @tls://1.1.1.1 whoami.cloudflare | _parse_doggo_response fromjson
)

_get_ip_cloudflare() (
  doggo --json --type=TXT --class=CH @1.1.1.1 whoami.cloudflare | _parse_doggo_response fromjson
)

_get_ip_opendns_tls() (
  doggo --json @tls://dns.opendns.com myip.opendns.com | _parse_doggo_response
)

_get_ip_opendns() (
  doggo --json @resolver1.opendns.com myip.opendns.com | _parse_doggo_response
)

_get_ip_ipinfo() (
  wget -O- -q https://ipinfo.io/json | jq -re '.ip'
)

_get_configmap_ip() (
  kubectl get configmap "$CONFIGMAP_NAME" --output=jsonpath='{.data.ip}'
)

for handler in $HANDLERS; do
    if ip="$("_get_ip_$handler")" && [[ -n "$ip" ]]; then
        echo "Got IP from handler: $handler"
        break
    fi
    echo "Failed to get public IP from handler: $handler"
done
if [[ -z "$ip" ]]; then
  echo "All handlers failed"
  exit 1
fi

configmap_ip="$(_get_configmap_ip || true)"
if [[ "$ip" != "$configmap_ip" ]]; then
  printf 'Patching configmap/%s with new IP: "%s" to "%s"\n' "$CONFIGMAP_NAME" "$configmap_ip" "$ip" >&2

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
