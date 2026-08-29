# OmniNest Backend

OmniNest Backend is the service layer for a self-hosted personal digital life center. It provides authentication, RBAC, file metadata, object storage integration, search, async task orchestration, configuration management, and media service APIs for files, video, music, and reading scenarios.

## Project Goals

OmniNest is designed for users who want to keep personal files and media under their own control instead of spreading them across unrelated cloud drives, media libraries, note tools, and download managers. The backend focuses on:

- unified file asset management backed by PostgreSQL metadata and MinIO object storage;
- built-in account login, local JWT sessions, and role-based access control;
- async processing for indexing, media probing, scraping, transcoding, external import, and offline download tasks;
- consistent APIs for Web, Android, and Desktop clients;
- a modular monolith structure that is simple to deploy but still keeps module boundaries clear.

## Architecture

The backend is a Maven multi-module Spring Boot application. The same application artifact runs as an API, Worker, or Scheduler process according to the configured runtime role.

```text
backend/
  pom.xml                 # parent aggregator and dependency management
  omninest-common/        # shared API response, errors, security, Redis, RabbitMQ, MinIO, rate limit, utilities
  omninest-system/        # auth, user, admin, config, task, notification, file nodes, uploads, shares, external storage, search
  omninest-media/         # video, music, reader, photos, media metadata and playback services
  omninest-worker/        # RabbitMQ consumers and async processors
  omninest-app/           # Spring Boot entrypoint, runtime config, Flyway migrations, final jar
```

The system remains a modular monolith: Maven modules enforce coarse boundaries, and `omninest-app` packages the final Spring Boot application. API and worker modes are selected through configuration rather than separate codebases.

## Tech Stack

- Java 21
- Spring Boot 4
- Spring Security with local JWT and RBAC
- Spring Data JPA / Hibernate
- PostgreSQL with Flyway migrations
- Redis for cache, rate limiting, and short-lived state
- RabbitMQ for async tasks and event fanout
- MinIO for object storage
- fastjson2 for JSON serialization in shared infrastructure
- Maven for build and test orchestration

## Core Flow

1. A user uploads a file, creates an offline download, or imports content from external storage.
2. The file content is stored in MinIO, while file nodes, ownership, metadata, upload sessions, shares, and task records are stored in PostgreSQL.
3. Domain services create task records and publish async work through RabbitMQ.
4. Worker consumers perform indexing, text extraction, media probing, video scraping, music metadata handling, transcoding, external import, or cleanup work.
5. API endpoints aggregate the latest metadata into file, video, music, reader, task, and admin views consumed by the Flutter clients.

## Main Modules

### System

- Built-in registration and login
- Access token and refresh token handling
- Current user context
- Super admin initialization
- Admin user and role management
- Config center and config history
- Task query and admin operations

### Storage

- File browser metadata
- Folder creation, rename, delete, restore, purge, favorites
- Share links and shared-with-me views
- Multipart upload sessions and pre-signed upload URLs
- Download URL generation
- Storage statistics
- Offline download tasks through Aria2
- External storage browsing and import through Rclone
- Search API

### Media

- Video dashboard, library, recent items, continue watching, favorites, history
- Movie, TV series, anime, collections, seasons, episodes, content assets
- Playback plans, progress sync, subtitles, stream endpoints
- Metadata scraping, NFO preview/export, scan tasks, probe tasks, transcode tasks
- Music dashboard, tracks, albums, artists, playlists, favorites, stream and playback plan APIs
- Reader dashboard, items, chapters, favorites, collections, progress APIs

### Worker

- File indexing
- Text extraction
- External storage import
- Offline download progress handling
- Media scraping
- Video transcoding

## Runtime Profiles

- `dev`: local defaults, verbose `com.omninest` logging, wider actuator exposure.
- `prod`: production-oriented external configuration, stricter management exposure.

The process role is controlled by:

```properties
OMNINEST_ROLE=api
```

Supported values are `api`, `worker`, and `scheduler`. API endpoints are active only in the API role. Worker and Scheduler roles start without an HTTP server.

## Local Dependencies

Start local infrastructure from the repository root:

```bash
cd deploy/dev
cp .env.example .env
docker compose up -d
```

Default ports:

| Service | Port |
| --- | --- |
| Backend API | `8080` |
| PostgreSQL | `5432` |
| Redis | `6379` |
| RabbitMQ | `5672` |
| RabbitMQ Management | `15672` |
| MinIO API | `9000` |
| MinIO Console | `9001` |
| Aria2 RPC | `6800` |
| Rclone RC | `5572` |

## Configuration

Runtime configuration is loaded from:

1. `omninest-app/src/main/resources/application.yml`
2. `application-dev.yml` or `application-prod.yml`
3. optional backend-root `.env`

Copy `backend/.env.example` to `backend/.env` for local overrides.

`OMNINEST_PROFILE=dev` uses local service defaults, verbose application logging,
Flyway actuator details, and the embedded Worker. `OMNINEST_PROFILE=prod` keeps
the same variable names but uses production-oriented overrides, disables the
embedded Worker, limits management exposure, disables API documentation, and
enables secure refresh-cookie defaults. All connection and credential values
remain overridable through environment variables; unset values use the profile
defaults and do not use Compose `:?` checks. The bundled credential defaults
exist for compatibility with the local development stack and must be replaced
when deploying the `prod` profile.

Important variables:

```properties
OMNINEST_PROFILE=dev
OMNINEST_SERVER_PORT=8080
OMNINEST_DB_URL=jdbc:postgresql://localhost:5432/omninest
OMNINEST_REDIS_HOST=localhost
OMNINEST_RABBITMQ_HOST=localhost
OMNINEST_MINIO_ENDPOINT=http://localhost:9000
OMNINEST_MINIO_PUBLIC_ENDPOINT=http://192.168.1.10:9000
OMNINEST_SECURITY_JWT_SECRET=change-me-omninest-local-jwt-secret-at-least-32-bytes
OMNINEST_SECURITY_CREDENTIAL_ENCRYPTION_KEY=<Base64-encoded-32-byte-key>
OMNINEST_ROLE=api
OMNINEST_SETUP_ENABLED=true
OMNINEST_SETUP_TOKEN=<random-token-at-least-32-characters>
OMNINEST_SETUP_PERSISTENT_STATE_ENABLED=true
OMNINEST_SETUP_WEB_BASE_URL=
OMNINEST_PHOTO_AI_ENDPOINT=http://localhost:8090
OMNINEST_PHOTO_AI_TIMEOUT_SECONDS=30
OMNINEST_READER_COMIC_CONSUME_IN_API=true
```

Do not commit real secrets or production `.env` files.

On a fresh database, configure `OMNINEST_SETUP_TOKEN` and open any OmniNest
client. For Flutter Web, `/setup` redirects to the same-origin `/#/setup` route,
or to `OMNINEST_SETUP_WEB_BASE_URL` when the frontend is hosted separately. The
responsive first-run wizard creates the initial `SUPER_ADMIN` and stores the
instance name, locale, and time zone.

With `OMNINEST_SETUP_PERSISTENT_STATE_ENABLED=true`, the singleton
`system_instances` row is authoritative and keeps setup closed after completion.
Set it to `false` to derive setup availability from the presence of a
`SUPER_ADMIN` instead. This recovery mode intentionally reopens setup if all
super-administrator assignments are removed. Account details are never sourced
from environment variables.

For Redis memory limits, RabbitMQ queue policies, monitoring thresholds, rollout,
and rollback in a non-container deployment, see
[`docs/infrastructure-capacity-runbook.md`](../docs/infrastructure-capacity-runbook.md).

## Database

Flyway migrations live under:

```text
omninest-app/src/main/resources/db/
```

The default schema is `omni`. Flyway is enabled by default in local development
and is controlled by the application profile, not by undocumented environment
variables.

## Commands

Run all backend tests:

```powershell
cd backend
mvn test
```

Run the API locally:

```powershell
cd backend
mvn -pl omninest-app -am spring-boot:run -Dspring-boot.run.profiles=dev
```

Run the Worker process:

```bash
cd backend
OMNINEST_ROLE=worker \
mvn -pl omninest-app -am spring-boot:run -Dspring-boot.run.profiles=dev
```

Run the Scheduler process:

```bash
cd backend
OMNINEST_ROLE=scheduler \
mvn -pl omninest-app -am spring-boot:run -Dspring-boot.run.profiles=dev
```

If Maven is not using JDK 21, set `JAVA_HOME` first:

```powershell
$env:JAVA_HOME='D:\Development\JAVA\jdk-21'
$env:Path="$env:JAVA_HOME\bin;$env:Path"
```

## API Shape

All business APIs use the `/api/v1` prefix and return the shared response envelope:

```json
{
  "code": 200,
  "message": "成功",
  "data": {}
}
```

Representative endpoint groups:

- `/api/v1/auth/*`
- `/api/v1/me`
- `/api/v1/admin/*`
- `/api/v1/files/*`
- `/api/v1/uploads/*`
- `/api/v1/external-storages/*`
- `/api/v1/offline-downloads/*`
- `/api/v1/search`
- `/api/v1/video/*`
- `/api/v1/music/*`
- `/api/v1/reader/*`

## Development Notes

- Keep reusable infrastructure in `omninest-common`.
- Controllers should delegate to services and avoid business-heavy request handlers.
- Repositories should stay inside their owning module.
- Cross-module behavior should go through services or domain events.
- Worker consumers should orchestrate work and delegate complex business logic to services.
- Prefer adding focused tests near the module being changed.
