# OmniNest Frontend

前端是基于 Flutter 的统一客户端，目标平台包括 Web、Android、Windows 和 macOS。各平台保持相同的信息架构，根据窗口尺寸和输入方式调整布局、导航和交互密度。

## 功能模块

| 模块 | 主要职责 |
| --- | --- |
| `portal` | 工作台、动态背景、最近内容、通知和模块入口 |
| `files` | 文件列表、目录、上传下载、搜索、预览和生命周期操作 |
| `photos` | 相册、图片导入、详情、元数据和图像分析结果 |
| `video` | 影视库、影片详情、播放、字幕和播放进度 |
| `music` | 本地/外部音乐、搜索、队列、歌词、封面和播放控制 |
| `reader` | 书籍与漫画导入、目录、阅读、书签、批注和阅读进度 |
| `admin` | 系统管理、权限、配置、任务、审计和监控 |
| `profile` / `settings` | 个人资料、主题、账号安全和客户端偏好 |
| `setup` | 首次安装和实例初始化向导 |

## 技术与分层

- Riverpod 负责业务状态；go_router 负责路由；Dio 负责 HTTP；drift 和安全存储分别负责本地数据与敏感凭据。
- 功能目录采用 `domain`、`data`、`application`、`presentation` 分层。
- `domain` 不依赖 Flutter 或网络实现；`data` 负责 DTO、API、缓存和 Repository；`application` 负责 Notifier、Controller 和业务流程；`presentation` 只负责展示、输入、导航和反馈。
- 页面不直接访问 Dio、数据库、MinIO 或宿主机文件系统。上传、导入、删除、解析、轮询和同步等长流程由 application/Repository 持有，页面销毁不会隐式取消已提交的后台任务。
- 所有异步操作都必须处理 `mounted`、Provider 生命周期、请求竞态、重复提交、路由退出和资源释放，避免 `ref` 越界、Navigator 锁定、Duplicate GlobalKey 等 Flutter 框架异常。

## 环境配置

开发环境模板位于 `frontend/env/dev.example.json`。首次运行可在 Git Bash 中创建本地配置：

```bash
cd frontend
test -f env/dev.json || cp env/dev.example.json env/dev.json
```

常用地址包括 API、WebSocket 和 Web 公网地址。真实凭据和生产配置不得提交。

## 本地开发

```bash
cd frontend
flutter pub get
flutter devices
flutter run -d windows
```

也可以将设备 ID 替换为 Android 设备，或使用 Chrome 启动 Web：

```bash
flutter run -d <device-id>
flutter run -d chrome
```

## 构建

```bash
flutter build web --release
flutter build apk --release
flutter build appbundle --release
flutter build windows --release
flutter build macos --release
```

生产 Web 构建由 `deploy/prod/nginx/Dockerfile` 完成并由 Nginx 托管，同时代理 API、WebSocket 和 MinIO。部署入口见 [../deploy/prod/README.md](../deploy/prod/README.md)。

Windows 和 macOS 当前命令生成 Flutter 平台构建产物，仓库没有默认集成 Inno Setup、MSIX 或 macOS DMG/PKG 的安装包流水线。若需要向终端用户分发，应在构建产物验证通过后单独增加对应平台的签名、安装包和更新策略。

## 代码与验证

```bash
dart format lib test
flutter analyze
flutter test
git diff --check
```

涉及导入、上传、删除、阅读器、播放器、路由或窗口尺寸时，应补充相应的 Widget、集成或响应式回归测试，至少覆盖页面中途退出、重复点击、请求竞态和主题切换。

## 相关入口

- [根目录项目总览](../README.md)
- [英文前端指南](README.en.md)
- [后端开发指南](../backend/README.md)
- [开发环境部署](../deploy/dev/README.md)
