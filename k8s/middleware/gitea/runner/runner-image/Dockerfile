FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 基础工具 + 网络/调试工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git jq yq gettext-base \
    dnsutils netcat-openbsd iproute2 iputils-ping \
    openssl vim less procps \
    && rm -rf /var/lib/apt/lists/*

# Docker CLI (不装 daemon, 复用宿主机 docker.sock)
COPY docker-cli /usr/local/bin/docker
RUN chmod +x /usr/local/bin/docker

# kubectl
COPY kubectl /usr/local/bin/kubectl
RUN chmod +x /usr/local/bin/kubectl

# helm
COPY helm /usr/local/bin/helm
RUN chmod +x /usr/local/bin/helm

# bash 为默认 shell
SHELL ["/bin/bash", "-c"]
