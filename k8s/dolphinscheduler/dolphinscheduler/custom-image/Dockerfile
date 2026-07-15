# Stage 1: 下载 SeaTunnel 客户端
FROM alpine:3.18 AS seatunnel-client

ARG SEATUNNEL_VERSION=2.3.13
ARG SEATUNNEL_URL=https://gh-proxy.com/https://github.com/apache/seatunnel/releases/download/${SEATUNNEL_VERSION}/apache-seatunnel-${SEATUNNEL_VERSION}-bin.tar.gz

RUN apk add --no-cache curl tar
RUN curl -fsSL "$SEATUNNEL_URL" -o /tmp/seatunnel.tar.gz && \
    tar xzf /tmp/seatunnel.tar.gz -C /tmp && \
    mv /tmp/apache-seatunnel-${SEATUNNEL_VERSION} /opt/seatunnel && \
    rm -rf /tmp/seatunnel.tar.gz /opt/seatunnel/connectors /opt/seatunnel/connectors-seatunnel && \
    rm -rf /opt/seatunnel/bin/seatunnel-cluster.sh /opt/seatunnel/config/hazelcast*.yaml

# Stage 2: 最终 DS Worker 镜像
FROM apache/dolphinscheduler-worker:3.1.7

USER root

# 安装 Python 3.10 + 常用开发工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-dev \
    python3.10-venv \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    build-essential \
    curl \
    vim-tiny \
    procps \
    && ln -sf /usr/bin/python3.10 /usr/bin/python3 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# 安装基础 Python 包
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# 拷贝 SeaTunnel 客户端（仅保留 client 模块，不含 connectors）
COPY --from=seatunnel-client /opt/seatunnel /opt/seatunnel

ENV SEATUNNEL_HOME=/opt/seatunnel \
    PATH=$PATH:/opt/seatunnel/bin \
    PYTHONPATH=/opt/dolphinscheduler/python:$PYTHONPATH

USER dolphinscheduler

LABEL maintainer="Apache DolphinScheduler" \
      version="3.1.7" \
      description="DolphinScheduler Worker with Python 3.10 and SeaTunnel client"
