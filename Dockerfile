#syntax=docker/dockerfile:1

FROM alpine:3.23.3 AS base

FROM base AS doggo
WORKDIR /app
ARG DOGGO_VERSION="v1.1.5"
ARG TARGETARCH
RUN <<EOT
  set -eux
  arch="$(echo "$TARGETARCH" | sed 's/amd64/x86_64/')"
  wget -O- "https://github.com/mr-karan/doggo/releases/download/${DOGGO_VERSION}/doggo_${DOGGO_VERSION#v}_Linux_${arch}.tar.gz" \
    | tar xzf - --strip-components=1
EOT

FROM base

ARG USERNAME=external-dns
ARG UID=1000
ARG GID=$UID
ARG KUBERNETES_VERSION="v1.35.2"
ARG TARGETARCH
RUN <<EOT
  set -eux

  apk add --no-cache jq

  wget -P /usr/local/bin "https://dl.k8s.io/release/$KUBERNETES_VERSION/bin/linux/$TARGETARCH/kubectl"
  chmod +x /usr/local/bin/kubectl

  printf '%s  /usr/local/bin/kubectl' "$(wget -O- "https://dl.k8s.io/$KUBERNETES_VERSION/bin/linux/$TARGETARCH/kubectl.sha256")" \
    | sha256sum -c

  addgroup -g "$GID" "$USERNAME"
  adduser -S -u "$UID" -G "$USERNAME" "$USERNAME"
EOT

COPY --from=doggo /app/doggo /usr/local/bin/doggo

USER $UID

COPY entrypoint.sh /
CMD /entrypoint.sh
