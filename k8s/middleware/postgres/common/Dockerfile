# 自定义 CNPG PostgreSQL 镜像（含 pg_cron / pg_partman）
#
# CNPG 官方镜像不含 pg_cron 和 pg_partman，
# 需要在此基础镜像上额外安装。
#
# 用法: bash build.sh
# 输出: ghcr.io/<你的用户名>/postgresql-custom:17

FROM ghcr.io/cloudnative-pg/postgresql:17

LABEL maintainer="sre-lab"
LABEL description="CloudNativePG PostgreSQL 17 image with pg_cron and pg_partman extensions"

USER root

# 安装额外的 PostgreSQL 扩展
# pg_cron: 基于 cron 的任务调度
# pg_partman: 分区管理
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      postgresql-17-cron \
      postgresql-17-partman && \
    apt-get purge -y --auto-remove && \
    rm -rf /var/lib/apt/lists/* /var/cache/* /var/log/*

# 恢复 CNPG 推荐的 uid
USER 26
