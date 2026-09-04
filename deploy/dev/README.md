# 开发环境

该编排只启动 OmniNest 的本地依赖。后端使用 Maven 或 IDE 运行，Flutter 使用对应开发工具运行。

```bash
cp .env.example .env
docker compose up -d
```

后端裸进程变量从 `../../backend/.env` 读取，模板位于
`../../backend/.env.example`。Compose 的 `.env` 不会自动注入后端裸进程。

## ClamAV 可选开关

ClamAV 是可选服务，通过 `.env` 的 `COMPOSE_PROFILES=clamav` 控制：
保留该行时 `docker compose up -d` 会启动 ClamAV 并启用病毒扫描；注释掉该行则
不启动容器。两套模式必须与后端同步：

- 带病毒扫描（默认）：`COMPOSE_PROFILES=clamav`，且 `backend/.env` 保持
  `OMNINEST_CLAMAV_ENABLED=true`。
- 不带病毒扫描：注释 `COMPOSE_PROFILES=clamav`，并把 `backend/.env` 改为
  `OMNINEST_CLAMAV_ENABLED=false`，可释放约 1 GB 级内存。

容器与后端开关必须一致：容器未启动而后端仍启用扫描时，安全检查按 fail-closed
处理，上传会因"ClamAV 安全扫描不可用"被拒绝。

`backend/`、`ai-sidecar/`、`netease-api/` 包含完整 Dockerfile，便于与生产环境直接比较。
开发编排默认只构建图片分析侧车和网易云 API，后端仍由 Maven 或 IDE 运行；图片分析侧车
继续使用项目 `../../ai-sidecar` 作为源码构建上下文。
