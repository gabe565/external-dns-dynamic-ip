#syntax=docker/dockerfile:1.10

FROM alpine:3.20.3

ARG USERNAME=external-dns
ARG UID=1000
ARG GID=$UID
ARG KUBERNETES_VERSION="v1.31.1"
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

COPY --from=ghcr.io/mr-karan/doggo:v1.0.5 /usr/bin/doggo /usr/local/bin/doggo

USER $UID

COPY entrypoint.sh /
CMD /entrypoint.sh
