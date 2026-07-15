# SeaTunnel Engine 2.3.13 镜像（含完整 connectors）
FROM alpine:3.18 AS download

ARG SEATUNNEL_VERSION=2.3.13
ARG SEATUNNEL_URL=https://gh-proxy.com/https://github.com/apache/seatunnel/releases/download/${SEATUNNEL_VERSION}/apache-seatunnel-${SEATUNNEL_VERSION}-bin.tar.gz

RUN apk add --no-cache curl tar
RUN curl -fsSL "$SEATUNNEL_URL" -o /tmp/seatunnel.tar.gz && \
    tar xzf /tmp/seatunnel.tar.gz -C /tmp && \
    mv /tmp/apache-seatunnel-${SEATUNNEL_VERSION} /opt/seatunnel && \
    rm -rf /tmp/seatunnel.tar.gz

# 最终镜像
FROM eclipse-temurin:8-jre

ARG SEATUNNEL_VERSION=2.3.13

LABEL maintainer="Apache SeaTunnel" \
      version="${SEATUNNEL_VERSION}" \
      description="SeaTunnel Engine with full connectors"

ENV SEATUNNEL_HOME=/opt/seatunnel \
    PATH=$PATH:/opt/seatunnel/bin

RUN mkdir -p /opt/seatunnel

COPY --from=download /opt/seatunnel /opt/seatunnel

WORKDIR /opt/seatunnel

EXPOSE 5801 5802

ENTRYPOINT ["/opt/seatunnel/bin/seatunnel-cluster.sh"]
CMD ["-d"]
