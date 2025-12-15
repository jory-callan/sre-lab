# docker-compose

此目录下为 docker-compose 相关的配置文件，核心是用于开发环境的快速部署
使用之前需要先创建网络

```shell
# 192.168.0.0/20 # 范围 192.168.0.0 - 192.168.15.255 . 共 2^12 - 2 = 4094 个 IP 地址
docker network create --driver bridge --subnet=192.168.0.0/20 env-dev

docker network create --driver bridge --subnet=172.21.0.0/16 env-dev

# 其他相关指令
docker network ls
docker network inspect env-dev
docker network rm env-dev
```

## docker compose 常用命令

```shell
# 启动
docker compose -f xxx.yml up -d
# 停止
docker compose -f xxx.yml down
# 重启容器
docker compose -f xxx.yml restart
# 查看容器状态
docker compose -f xxx.yml ps
# 查看日志
docker compose -f xxx.yml logs -f
# 查看容器占用资源
docker compose -f xxx.yml stats
```
## docker compose 配置文件常用配置项

以 nginx 配置文件为例

```yaml
version: "3.7"
services:
  nginx:
    image: nginx:1.28-alpine # 镜像名称
    container_name: nginx # 容器名称, 默认为服务名称
    restart: always  # 容器重启策略
    working_dir: /etc/nginx  # 容器内工作目录
    user: "101:101"  # 容器内运行用户
    privileged: true  # 特权模式，容器内可以使用 host 网络
    networks:  # 加入已存在的网络
      - env-dev # 容器网络名称, 默认为服务名称
    # network_mode: host # 容器网络模式, host 模式表示容器使用 host 网络
    ports:
      - 81:80 # 容器端口映射, 将宿主机的 81 端口映射到容器的 80 端口
    volumes: # 容器卷挂载, 格式为 host_path:container_path:mount_type , mount_type有3种,ro表示只读, rw表示读写, none表示不挂载
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./html:/usr/share/nginx/html:ro
      - ./logs:/var/log/nginx:rw
    environment: # 环境变量配置
      - TZ=Asia/Shanghai # 设置时区为上海
    command: nginx -g "daemon off;" # 容器启动命令, 默认为镜像的 ENTRYPOINT 命令
    # depends_on: # 依赖服务, 表示该服务依赖于其他服务, 其他服务启动后, 该服务才会启动
    #   - postgres # 依赖的服务名称
    healthcheck:  # 健康检查配置
      test: ["CMD", "curl", "-f", "http://localhost/"]  # 使用 curl 检查 HTTP 状态
      interval: 30s  # 每 30 秒检查一次
      timeout: 10s  # 每次检查的超时时间为 10 秒
      retries: 3  # 如果失败，重试 3 次
      start_period: 40s  # 容器启动后 40 秒内不进行健康检查
    deploy:  # 资源限制配置
      resources:
        limits:
          cpus: "0.5"  # CPU 使用上限为 0.5 核心,1 代表
          memory: 50M  # 内存使用上限为 50MB
        reservations:
          cpus: "0.1"  # CPU 预留为 0.1 核心
          memory: 20M  # 内存预留为 20MB

# 定义自定义网络
networks:
  env-dev:  # 定义自定义网络
    name: env-dev # 自定义网络名称, 默认是服务名称
    driver: bridge
    ipam:  # 自定义 IP 网段
      config:
        - subnet: 192.168.0.0/24 # 自定义 IP 网段, 默认为 172.28.0.0/16
  env-all:
    external: true

# 使用已经存在的网络
# networks:
#   env-all2:
#       external: true

```

## docker build 常用命令

```shell
# 构建镜像 前面是 tag 后面是 Dockerfile 所在目录
docker build -t nginx:1.28-alpine ./
# 超时时间
docker build --build-arg BUILD_TIMEOUT=30m  -t nginx:1.28-alpine ./
```

