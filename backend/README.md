# OmniNest Backend

后端负责统一 API、身份认证、文件能力、媒体业务、后台任务和系统管理。它采用模块化单体结构，同一套代码可以按运行角色启动 API、Worker 或 Scheduler，不把业务模块拆成相互独立的微服务。

## 技术基线

- Java 21、Maven、Spring Boot 4.0.x。
- Spring Web MVC、Spring Security、Spring Data JPA/Hibernate 和 Flyway。
- PostgreSQL 保存业务元数据、权限、配置、任务和派生状态。
- RabbitMQ 处理需要持久化、进度、重试、恢复或调度的后台任务。
- Redis 提供缓存、短期状态、并发控制和限流支持。
- MinIO 与受控 Storage Provider 提供原始内容和派生资产访问。
- Lucene 负责默认的嵌入式搜索，Tika 用于内容识别和文本提取。

## 运行角色

| 角色 | 职责 |
| --- | --- |
| `api` | 对外提供 REST API、认证授权、文件和媒体访问、任务查询及实时连接 |
| `worker` | 消费 RabbitMQ 后台任务，执行索引、解析、缩略图、媒体和安全处理 |
| `scheduler` | 执行清理、恢复、重试、保留策略和定时调度 |

通过 `OMNINEST_ROLE` 或 Spring Profile 选择运行配置。API、Worker、Scheduler 可以使用同一个应用镜像，以不同角色运行。

## 模块

| 模块 | 责任 |
| --- | --- |
| `omninest-common` | 公共响应、异常、基础模型和跨模块通用能力 |
| `omninest-infrastructure` | 数据库、缓存、消息、存储、搜索和运行时基础设施 |
| `omninest-system` | 用户、角色、权限、配置、通知、任务、审计和系统状态 |
| `omninest-file` | FileNode、内容 Provider、上传下载、版本、回收站和物理存储生命周期 |
| `omninest-media` | Movies、Music、Photos、Reader 等媒体领域服务和元数据 |
| `omninest-worker` | 后台消费者、任务执行与重试编排 |
| `omninest-app` | Spring Boot 启动入口、HTTP API、运行配置和迁移资源 |

## 存储边界

业务模块只持有业务 ID 和内容访问能力，不直接操作 MinIO Client、Rclone、宿主机绝对路径或底层 `Path`。所有内容读取、权限预检、Range 读取、staging 和 Provider 能力判断由 File 模块统一处理。

Video 可以使用管理员登记的 `LOCAL_FILESYSTEM` 只读来源。该来源不提供重命名、移动、删除、复制、分享、版本或离线下载语义；只有显式导入为受管内容后才具备 MinIO 托管能力。大型内容和派生文件必须走流式或后台任务路径。

## 配置

主配置位于 `omninest-app/src/main/resources/application.yml`，按需加载工作目录中的 `.env`。模板和模块配置说明位于 `backend/.env.example`。常用变量包括：

- `OMNINEST_PROFILE`：默认 `dev`，选择 Spring 配置。
- `OMNINEST_ROLE`：默认 `api`，选择运行角色。
- PostgreSQL、RabbitMQ、Redis、MinIO、Rclone 和图像分析 Sidecar 的连接配置。
- JWT、公开地址、CORS、上传和媒体限制等系统参数。

默认值用于本地开发和配置校验，生产环境必须显式检查公开地址、凭据、私有存储和安全策略。真实密码、Token、密钥和生产配置不得提交。

## 本地开发

先按 [deploy/dev/README.md](../deploy/dev/README.md) 启动依赖，再在 Git Bash 中执行：

```bash
cd backend
mvn -q test
mvn -pl omninest-app spring-boot:run -Dspring-boot.run.profiles=dev
```

构建应用镜像所需的 JAR：

```bash
mvn -q -pl omninest-app -am -DskipTests package
```

首次启动空数据库时，Flyway 负责 `V001__init_schema.sql` 和 `V002__builtin_catalog.sql`。两份脚本构成当前基线；若当前版本允许重写基线，结构变更和内置目录变更应分别同步到对应文件。人工维护脚本位于 `omninest-app/src/main/resources/db/manual/`。

## API 与任务

- REST API 使用 `/api/v1` 前缀，错误响应包含稳定业务错误码。
- 身份由本地 JWT 的 `sub` 映射到数据库用户，权限由角色、权限及其映射决定。
- 需要跨请求持续执行的任务先落库，再在事务提交后投递 RabbitMQ；任务状态、重试和死信记录可查询。
- MinIO bucket 默认私有，文件下载和媒体流通过受控访问或短期签名地址提供。
- 外部 URL 抓取、离线下载、字幕和元数据请求必须经过协议、DNS、IP 和重定向校验。

## 验证

常规后端变更至少执行：

```bash
mvn -q test
git diff --check
```

涉及数据库、权限、任务、存储或安全边界时，还应补充对应的单元测试或 Testcontainers 集成测试，并记录实际未执行的验证项。

## 相关入口

- [根目录项目总览](../README.md)
- [英文后端指南](README.en.md)
- [生产部署](../deploy/prod/README.md)
- [图像分析侧车](../ai-sidecar/README.md)
