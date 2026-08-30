# OmniNest

OmniNest 是一个面向个人和家庭场景的自托管数字生活中心。它将文件管理、影视、音乐、相册和阅读能力组织在同一套账户、存储、任务与权限体系中，支持 Web、Android 和 Desktop 客户端。

项目仍在持续开发中。根 README 只说明产品能力和整体入口，具体实现、开发命令和运行约束分别维护在后端与前端 README 中。

## 系统界面预览

下列图片来自前端 Workbench 的可重复 UI 测试基线，展示桌面端和移动端在浅色、深色主题下的实际布局。它们用于说明当前系统的视觉方向和跨平台信息架构；各业务模块的完整界面以实际构建版本为准。

<table>
  <tr>
    <th>桌面端 · 深色</th>
    <th>桌面端 · 浅色</th>
  </tr>
  <tr>
    <td><img src="frontend/test/theme/goldens/workbench_desktop_dark.png" alt="OmniNest 桌面端深色主题工作台" width="600"></td>
    <td><img src="frontend/test/theme/goldens/workbench_desktop_light.png" alt="OmniNest 桌面端浅色主题工作台" width="600"></td>
  </tr>
  <tr>
    <th>移动端 · 深色</th>
    <th>移动端 · 浅色</th>
  </tr>
  <tr>
    <td><img src="frontend/test/theme/goldens/workbench_mobile_dark.png" alt="OmniNest 移动端深色主题工作台" width="300"></td>
    <td><img src="frontend/test/theme/goldens/workbench_mobile_light.png" alt="OmniNest 移动端浅色主题工作台" width="300"></td>
  </tr>
</table>

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

## 核心使用路径

1. 完成实例初始化并登录，Portal 提供最近内容、任务状态、通知和各个模块的统一入口。
2. 在 File Manager 中上传文件、整理目录或访问受控的本地媒体来源，系统负责权限、版本、回收站和存储生命周期。
3. 将内容交给 Photos、Movies、Music 或 Reader 使用；模块保存业务元数据和进度，原始内容仍由统一的文件能力读取。
4. 对需要解析、缩略图、索引、媒体探测或安全扫描的操作，前端显示后台任务状态，任务可在离开页面后继续执行。
5. 通过个人中心切换浅色、深色或跟随系统主题，并在不同尺寸的桌面、平板和手机窗口中使用相同的信息架构。

## 产品特点

- **统一入口**：Portal、全局搜索、通知、个人中心和主题能力跨模块复用，减少不同页面之间的操作差异。
- **内容与业务分离**：文件内容、业务元数据和派生资源分别管理，媒体模块可以共享同一份内容而不重复上传。
- **本地优先的自托管体验**：系统可在个人服务器或家庭网络中部署，外部服务作为可选能力，不要求用户把内容交给第三方平台。
- **可追踪的后台处理**：导入、解析和索引等流程具有任务状态和错误反馈，便于用户了解内容何时可用以及失败原因。
- **三端一致**：Web、Android、Windows 和 macOS 保持相同产品结构，同时针对触控、鼠标、键盘和窗口尺寸调整交互。

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
