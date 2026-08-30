# 生产环境

生产编排使用同一 backend 镜像启动 API、Worker 和 Scheduler。Nginx 构建并
托管 Flutter Web，统一代理 API、WebSocket 和 MinIO。网易云 API 与图片分析侧车
只在 Compose 内部网络提供服务，不直接暴露宿主机端口。

`backend/`、`nginx/`、`ai-sidecar/`、`netease-api/` 包含生产环境使用的完整
Dockerfile 或运行脚本。Compose 从项目源码构建镜像，不复制业务源码到部署目录。

## 构建与启动

backend 镜像使用已经由 Maven 生成的应用 JAR：

```bash
cd ../../backend
mvn -q -pl omninest-app -am -DskipTests package

cd ../deploy/prod
cp .env.example .env
docker compose build
docker compose up -d
```

生产部署前必须重点修改 `.env` 中的数据库、RabbitMQ、MinIO、Rclone、JWT、
图片分析侧车凭据，以及公开地址。模板保留默认值用于单机 HTTP 验证，不会通过
Compose 的 required 语法阻止启动。

## 公开入口和 HTTPS

`OMNINEST_HTTPS_ENABLED=false` 时，Nginx 在配置的 HTTP 端口提供 Web/API，在 9000
端口代理 MinIO。Spring Boot 和 MinIO 只通过 Docker 内部网络通信；后端调试端口
仅绑定 `127.0.0.1`。

启用当前 Certbot Webroot/HTTP-01 方案时，宿主机 HTTP 入口必须使用 TCP 80，不能将
`OMNINEST_PUBLIC_HTTP_PORT` 改为其他端口。若 80 已被其他服务占用，应让现有公网
Nginx 负责 80/443，并将 ACME 挑战和反向代理按共存方案接入；不要仅修改这个变量
绕过校验。

启用域名 HTTPS 前设置：

```dotenv
OMNINEST_HTTPS_ENABLED=true
OMNINEST_PUBLIC_HOST=omni.example.com
CERTBOT_IDENTIFIER_TYPE=domain
CERTBOT_CERT_NAME=omninest-domain
CERTBOT_EMAIL=admin@example.com
OMNINEST_SECURITY_ALLOWED_ORIGINS=https://omni.example.com
OMNINEST_SETUP_WEB_BASE_URL=https://omni.example.com
OMNINEST_MINIO_PUBLIC_ENDPOINT=https://omni.example.com:9000
```

域名的 A 记录必须指向部署服务器，80、443 和 9000 端口必须可达。Nginx 在证书
尚未签发时只提供 ACME 验证和健康检查，其他请求返回 503；Certbot 签发成功后，
Nginx 会检测证书变化并自动切换到 TLS。Spring Boot 不直接加载证书。

公网 IPv4 证书使用：

```dotenv
OMNINEST_HTTPS_ENABLED=true
OMNINEST_PUBLIC_HOST=203.0.113.10
CERTBOT_IDENTIFIER_TYPE=ipv4
CERTBOT_CERT_NAME=omninest-ip
OMNINEST_SECURITY_ALLOWED_ORIGINS=https://203.0.113.10
OMNINEST_SETUP_WEB_BASE_URL=https://203.0.113.10
OMNINEST_MINIO_PUBLIC_ENDPOINT=https://203.0.113.10:9000
```

IPv4 模式使用 Certbot 5.4 的 `shortlived` Profile，证书有效期很短，因此 Certbot
默认每 12 小时检查续期。该模式只适合能通过公网 ACME 校验的 IPv4，不适用于
`192.168.0.0/16` 等私有地址。正式部署优先使用域名证书。

需要先验证 ACME 流程时可设置 `CERTBOT_STAGING=true`。测试证书不受客户端信任，
切换正式证书时应改用新的 `CERTBOT_CERT_NAME`，避免继续沿用 Staging 的续期配置。

查看签发状态：

```bash
docker compose logs --follow nginx certbot
```

## 从 IPv4 切换到域名

先添加域名 A 记录，然后在旧 IP 入口仍运行时预签域名证书：

```bash
docker compose run --rm \
  -e OMNINEST_PUBLIC_HOST=omni.example.com \
  -e CERTBOT_IDENTIFIER_TYPE=domain \
  -e CERTBOT_CERT_NAME=omninest-domain \
  certbot request-once
```

确认 `omninest-domain` 已签发后，再更新 `.env` 中的公开主机、证书名、CORS、Setup
URL 和 MinIO 公开地址，并执行：

```bash
docker compose up -d --force-recreate nginx certbot backend-api backend-worker backend-scheduler
```

旧 IP 证书仍保留在 Certbot 命名卷中，不会阻塞回滚。短期签名 URL 等待自然过期，
数据库不需要迁移。域名稳定前不启用 HSTS Preload。

本地影视目录以只读方式同时挂载给 backend 三种运行角色。Rclone、Aria2 和
Lucene 使用命名卷在容器间共享所需内容；PostgreSQL、Redis、RabbitMQ 和 MinIO
数据分别使用独立命名卷。

Nginx 使用固定内部地址作为后端可信代理身份。`OMNINEST_DOCKER_DYNAMIC_IP_RANGE`
必须位于 `OMNINEST_DOCKER_SUBNET` 内，并且不能包含 `OMNINEST_NGINX_INTERNAL_IP`；
默认动态地址池为 `172.30.0.128/25`，因此不会与默认 Nginx 地址 `172.30.0.10` 冲突。
