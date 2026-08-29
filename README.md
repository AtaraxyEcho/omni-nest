# OmniNest

OmniNest 是一个自托管的个人数字生活中心，用于统一管理文件、影视、音乐、照片、阅读内容和系统配置。本仓库采用单仓库结构，包含 Spring Boot 后端、Flutter 多端客户端、图片分析侧车与本地开发基础设施。

## 仓库结构

```text
backend/      Spring Boot API、Worker、Scheduler、Flyway 与测试
frontend/     Flutter Web、Android、Windows 与测试
ai-sidecar/   Photos 图片分析侧车服务
deploy/       开发与生产 Docker 部署配置
```

## 本地基础设施

```bash
cd deploy/dev
cp .env.example .env
docker compose up -d
```

`deploy/dev/.env.example` 只描述开发 Compose 变量；后端裸进程变量见 `backend/.env.example`。生产部署见 `deploy/prod/README.md`。

## 后端

```bash
cd backend
mvn -q -pl omninest-app -am clean test
```

默认使用 `dev` Profile，后端端口为 `8080`。应用配置和本地依赖连接参数通过 `backend/.env.example` 中的环境变量覆盖。

## 前端

```bash
cd frontend
flutter pub get
flutter analyze
flutter test
```

Flutter 运行时地址通过 `--dart-define` 或 `--dart-define-from-file` 注入，具体变量见 `frontend/README.md`。
