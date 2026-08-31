# OmniNest

OmniNest is a self-hosted digital life center for personal and family use. It brings file management, movies, music, photos, and reading into one account, storage, task, and permission system, with Web, Android, and Desktop clients.

The project is under active development. This root README focuses on product capabilities and project entry points. Implementation details, development commands, and runtime constraints are maintained in the backend and frontend guides.

## System preview
<table>
  <tr>
    <th>Portal workspace</th>
    <th>Music player</th>
  </tr>
  <tr>
    <td><img src="imgs/portal_page.png" alt="OmniNest Portal workspace page" width="600"></td>
    <td><img src="imgs/music_player_page.png" alt="OmniNest music player page" width="600"></td>
  </tr>
  <tr>
    <th>Reader</th>
    <th>Setup wizard</th>
  </tr>
  <tr>
    <td><img src="imgs/reader_view_page.png" alt="OmniNest reader page" width="600"></td>
    <td><img src="imgs/setup_page.png" alt="OmniNest setup wizard page" width="600"></td>
  </tr>
</table>

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

## Core user journeys

1. Complete instance setup and sign in. Portal provides recent content, task state, notifications, and unified module entry points.
2. Upload files, organize folders, or access controlled local media sources through File Manager. Permissions, versions, recycle-bin behavior, and storage lifecycle are managed centrally.
3. Use the content from Photos, Movies, Music, or Reader. Each module owns its metadata and progress while reading original content through shared file capabilities.
4. For imports, parsing, thumbnails, indexing, media probing, and security scans, the client displays background-task status. A task can continue after the user leaves the current page.
5. Switch between light, dark, and system themes from the profile area and keep the same information architecture across desktop, tablet, and phone layouts.

## Product principles

- **One entry point**: Portal, global search, notifications, profile, and theme controls are shared across modules to reduce interaction differences.
- **Separated content and business data**: File content, business metadata, and derived assets have separate responsibilities, allowing modules to reuse the same content without duplicate uploads.
- **Self-hosted and local-first**: OmniNest can run on a personal server or home network. External services are optional and do not need to own the user's content.
- **Traceable background processing**: Imports, parsing, and indexing expose task state and failure feedback so users know when content is ready and why a task failed.
- **Consistent across platforms**: Web, Android, Windows, and macOS share the same product structure while adapting to touch, mouse, keyboard, and window-size differences.

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
