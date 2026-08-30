# OmniNest

OmniNest 是一个面向个人和家庭场景的自托管数字生活中心。它将文件管理、影视、音乐、相册和阅读能力组织在同一套账户、存储、任务与权限体系中，支持 Web、Android 和 Desktop 客户端。

项目仍在持续开发中。根 README 只说明产品能力和整体入口，具体实现、开发命令和运行约束分别维护在后端与前端 README 中。

## 功能概览

| 模块 | 主要能力 |
| --- | --- |
| Portal | 统一工作台、动态背景、最近内容、通知和跨模块入口 |
| File Manager | 文件上传、目录管理、搜索、预览、下载、回收站及存储生命周期管理 |
| Photos | 图片导入、相册浏览、缩略图、元数据、位置和图像分析结果查看 |
| Movies | 影视库、海报与详情、视频播放、字幕、播放进度和本地媒体来源 |
| Music | 本地音乐库、外部音乐平台、播放队列、歌词/封面和播放进度 |
| Reader | EPUB 等书籍导入、目录、文本阅读、漫画页面阅读、书签、批注和阅读进度 |
| Admin | 用户、角色权限、系统配置、后台任务、操作审计、通知和运行状态管理 |
| Profile | 个人资料、主题切换、账号安全和个人偏好 |

## 客户端与服务

- Web、Android、Windows 和 macOS 客户端统一使用 Flutter 实现。
- 后端是 Spring Boot 模块化单体，按 API、Worker、Scheduler 三种运行角色执行不同职责。
- 文件原始内容由受控存储 Provider 管理，MinIO 负责默认托管内容和派生资产；部分影视内容可以使用管理员登记的只读本地来源。
- PostgreSQL 保存业务元数据、权限、配置和任务状态；RabbitMQ 负责需要持续执行、重试或恢复的后台任务；Redis 用于缓存、短期状态和并发控制。
- Photos 的图像分析是可选的独立 Sidecar 能力，具体边界见 [ai-sidecar/README.md](ai-sidecar/README.md)。

## 仓库导航

| 目录 | 内容 | 说明 |
| --- | --- | --- |
| [backend](backend/README.md) | 后端 API、Worker、Scheduler 和测试 | 后端架构、模块、配置和验证 |
| [frontend](frontend/README.md) | Flutter Web、Android、Desktop 客户端 | 功能模块、运行和构建方式 |
| [ai-sidecar](ai-sidecar/README.md) | Photos 图像分析侧车 | 分析能力、接口和容器说明 |
| [deploy](deploy/README.md) | dev/prod Docker 编排 | 开发依赖和生产部署入口 |

英文说明：

- [English overview](README.en.md)
- [Backend English guide](backend/README.en.md)
- [Frontend English guide](frontend/README.en.md)

## 快速开始

开发环境的依赖编排、环境变量和启动顺序见 [deploy/dev/README.md](deploy/dev/README.md)。生产部署入口见 [deploy/prod/README.md](deploy/prod/README.md)，其中包含 Nginx、可选 HTTPS 和容器构建说明。

后端和前端的独立运行命令不在根 README 重复维护，分别以 [backend/README.md](backend/README.md) 和 [frontend/README.md](frontend/README.md) 为准。

## 许可证与状态

当前仓库处于持续开发阶段，发布策略、许可证和部署安全参数以实际版本说明为准。不要将真实密码、Token、密钥、外部服务凭据或生产环境配置提交到仓库。
