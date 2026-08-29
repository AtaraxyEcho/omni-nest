# 开发环境

该编排只启动 OmniNest 的本地依赖。后端使用 Maven 或 IDE 运行，Flutter 使用对应开发工具运行。

```bash
cp .env.example .env
docker compose up -d
```

后端裸进程变量从 `../../backend/.env` 读取，模板位于
`../../backend/.env.example`。Compose 的 `.env` 不会自动注入后端裸进程。

`backend/`、`ai-sidecar/`、`netease-api/` 包含完整 Dockerfile，便于与生产环境直接比较。
开发编排默认只构建图片分析侧车和网易云 API，后端仍由 Maven 或 IDE 运行；图片分析侧车
继续使用项目 `../../ai-sidecar` 作为源码构建上下文。
