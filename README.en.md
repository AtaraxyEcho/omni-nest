# OmniNest

OmniNest is a self-hosted digital life center for personal and family use. It brings file management, movies, music, photos, and reading into one account, storage, task, and permission system, with Web, Android, and Desktop clients.

The project is under active development. This root README focuses on product capabilities and project entry points. Implementation details, development commands, and runtime constraints are maintained in the backend and frontend guides.

## Features

| Area | Main capabilities |
| --- | --- |
| Portal | Unified workspace, dynamic backdrops, recent content, notifications, and cross-module entry points |
| File Manager | Uploads, folders, search, preview, downloads, recycle bin, and storage lifecycle management |
| Photos | Image import, albums, thumbnails, metadata, location details, and image-analysis results |
| Movies | Media library, posters and details, video playback, subtitles, playback progress, and local media sources |
| Music | Local music library, external music platforms, playback queue, lyrics/covers, and playback progress |
| Reader | EPUB and other book imports, catalogs, text reading, comic-page reading, bookmarks, annotations, and reading progress |
| Admin | Users, roles and permissions, system configuration, background tasks, audit records, notifications, and runtime status |
| Profile | Personal profile, theme selection, account security, and personal preferences |

## Clients and services

- Web, Android, Windows, and macOS clients are implemented with Flutter.
- The backend is a modular Spring Boot monolith with API, Worker, and Scheduler runtime roles.
- Controlled storage Providers own original content. MinIO is the default host for managed content and derived assets; selected video libraries may use administrator-registered read-only local sources.
- PostgreSQL stores business metadata, permissions, configuration, and task state. RabbitMQ handles background work that needs persistence, retries, or recovery. Redis provides caching, short-lived state, and concurrency control.
- Photo image analysis is an optional independent Sidecar capability. See [ai-sidecar/README.md](ai-sidecar/README.md) for its current boundary.

## Repository navigation

| Directory | Contents | Guide |
| --- | --- | --- |
| [backend](backend/README.md) | Backend API, Worker, Scheduler, and tests | Backend architecture, modules, configuration, and verification |
| [frontend](frontend/README.md) | Flutter Web, Android, and Desktop client | Features, local development, and builds |
| [ai-sidecar](ai-sidecar/README.md) | Photos image-analysis Sidecar | Analysis capabilities, API, and container notes |
| [deploy](deploy/README.md) | dev/prod Docker orchestration | Development dependencies and production deployment |

Chinese guides:

- [项目总览](README.md)
- [后端开发指南](backend/README.md)
- [前端开发指南](frontend/README.md)

## Quick start

See [deploy/dev/README.md](deploy/dev/README.md) for development dependency orchestration, environment variables, and startup order. See [deploy/prod/README.md](deploy/prod/README.md) for production deployment, including Nginx, optional HTTPS, and container builds.

The root guide does not duplicate backend and frontend commands. Use [backend/README.md](backend/README.md) and [frontend/README.md](frontend/README.md) as the source of truth for standalone development commands.

## License and status

The repository is under active development. Release policy, licensing, and deployment security parameters are defined by the applicable version documentation. Never commit real passwords, tokens, keys, external-service credentials, or production configuration.
