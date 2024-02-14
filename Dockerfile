#syntax=docker/dockerfile:1.6

FROM alpine:3.19

ARG USERNAME=external-dns
ARG UID=1000
ARG GID=$UID
ARG KUBERNETES_VERSION="v1.29.2"
ARG TARGETARCH
RUN <<EOT
  set -eux

  wget -P /usr/local/bin "https://dl.k8s.io/release/$KUBERNETES_VERSION/bin/linux/$TARGETARCH/kubectl"
  chmod +x /usr/local/bin/kubectl

  printf '%s  /usr/local/bin/kubectl' "$(wget -O- "https://dl.k8s.io/$KUBERNETES_VERSION/bin/linux/$TARGETARCH/kubectl.sha256")" \
    | sha256sum -c

  addgroup -g "$GID" "$USERNAME"
  adduser -S -u "$UID" -G "$USERNAME" "$USERNAME"
EOT

COPY --from=ghcr.io/mr-karan/doggo:v0.5.7 /usr/bin/doggo /usr/local/bin/doggo

USER $UID

COPY entrypoint.sh /
CMD /entrypoint.sh
