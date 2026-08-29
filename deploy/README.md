# Docker 部署

部署配置按运行环境分开维护：

- `dev/` 只启动本地开发依赖，后端和 Flutter 由开发工具直接运行。
- `prod/` 启动 API、Worker、Scheduler 和生产依赖。
- 每个环境内的 `backend/`、`ai-sidecar/`、`netease-api/` 保存对应镜像定义，打开目录即可查看全部 Docker 配置。

组件源码及其直接构建入口仍保留在组件目录中。dev/prod Compose 使用各自环境目录下的
Dockerfile，并继续以项目 `backend/`、`ai-sidecar/` 作为源码构建上下文。
两个环境中的公共构建逻辑必须同步维护；backend 的默认 Profile 等环境差异应保留在各自目录并明确说明。
