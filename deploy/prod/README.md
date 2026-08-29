# 生产环境

生产编排使用同一 backend 镜像启动 API、Worker 和 Scheduler。网易云 API 与
图片分析侧车只在 Compose 内部网络提供服务，不直接暴露宿主机端口。

`backend/`、`ai-sidecar/`、`netease-api/` 包含生产环境使用的完整 Dockerfile。
Compose 仍从项目 `../../backend` 与 `../../ai-sidecar` 读取源码和构建产物，不复制业务源码。

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
图片分析侧车凭据，以及 CORS 和 MinIO 对外地址。模板保留默认值用于单机验证，
不会通过 Compose 的 required 语法阻止启动。

本地影视目录以只读方式同时挂载给 backend 三种运行角色。Rclone、Aria2 和
Lucene 使用命名卷在容器间共享所需内容；PostgreSQL、Redis、RabbitMQ 和 MinIO
数据分别使用独立命名卷。
