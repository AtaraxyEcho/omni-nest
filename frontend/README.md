# OmniNest Frontend

OmniNest Frontend is the Flutter client for the OmniNest self-hosted personal digital life center. It targets Web, Android, Windows, macOS, and Linux from one feature-first codebase, with platform differences isolated behind adapters.

## Project Goals

The frontend provides one unified entry point for personal files, video, music, reading, external storage, task management, and admin operations. It is designed to solve the client-side problem of switching between separate tools for file browsing, media playback, metadata management, and progress tracking.

The current UI follows the HTML prototypes in `../html` and uses a dark-first Adaptive Tech-Minimalism style:

- fixed top bar on large screens;
- left navigation rail on Web/Desktop;
- bottom navigation on mobile widths;
- stable poster, book, and file card aspect ratios;
- module-specific dense management views where repeated operations matter.

## Tech Stack

- Flutter / Dart
- Riverpod for application state
- GoRouter for declarative routing and auth redirects
- Dio for HTTP API calls
- media_kit for video playback
- cached_network_image for remote artwork and thumbnails
- flutter_secure_storage for native secure session storage
- file_picker and file_selector for local file selection

## Directory Layout

```text
frontend/
  lib/
    main.dart
    app/                 # bootstrap, app widget, router, theme, environment, l10n
    core/                # auth, network, errors, security, storage, shared widgets, utilities
    platform/            # Web, Android, Desktop capability adapters
    features/
      portal/            # landing dashboard after login
      files/             # file browser, uploads, shares, recycle bin
      video/             # movie center, detail pages, player, metadata, series views
      music/             # music dashboard, library, playlists, player UI
      reader/            # reader center, book cards, item detail
      admin/             # admin dashboard, users, roles, config, tasks, monitoring
  test/                  # unit and widget tests
  integration_test/      # end-to-end app smoke tests
  web/                   # Web entry, manifest, icons, PDF.js assets
  android/               # Android host project
  windows/               # Windows host project
  macos/                 # macOS host project
  linux/                 # Linux host project
  tool/                  # local development scripts
```

## Main Features

### Authentication

- Login page
- Session restoration
- Access token injection
- Refresh handling through the shared auth/network layer
- Route guard that redirects unauthenticated users to `/login`

### Portal

- Main entry dashboard
- Navigation to files, video, music, reader, and admin sections
- Shared responsive shell behavior

### File Management

- File browser views
- Grid/list components
- Upload panel
- Favorites, recent files, recycle bin, share-related views
- File size and MIME helpers
- Download integration through platform adapters

### Video Center

- Movie dashboard and poster library
- Movies, TV shows, anime, collections, recent, continue watching, favorites, history
- Movie detail page
- Series detail and season/episode views
- Playback page with `media_kit`
- Metadata management
- Subtitle, NFO, scraping, scan, probe, and transcode task entry points

### Music Center

- Music dashboard
- Songs, albums, artists, playlists
- Queue and player bar
- Metadata and lyrics widgets
- Playback and favorite flows

### Reader Center

- Reader dashboard
- Book cards and library views
- Item detail page
- Progress and favorite-related state

### Admin

- Overview dashboard
- User management
- Role and permission operations
- Config management
- Task management
- Logs, monitoring, storage, and external storage views

## Configuration

Flutter reads API and WebSocket addresses at build time through `--dart-define`.
Copy the development template when local endpoints need to be changed:

```bash
cp env/dev.example.json env/dev.json
flutter run -d chrome --dart-define-from-file=env/dev.json --web-port 3000
```

The supported fields are `OMNINEST_API_BASE_URL`, `OMNINEST_WS_BASE_URL` and
`OMNINEST_WEB_BASE_URL`. The JSON file is local-only and must not contain tokens
or other secrets.

The default Web development URL is:

```text
http://localhost:3000
```

This origin is included in the backend CORS defaults.

## Commands

Install dependencies:

```powershell
flutter pub get
```

Run tests:

```powershell
flutter test
```

Run Flutter Web with the local helper script:

```powershell
.\tool\run_web.ps1
```

Run Web manually:

```powershell
flutter run -d chrome --web-port 3000
```

## Routing

Key routes are defined in `lib/app/router.dart`:

| Route | Page |
| --- | --- |
| `/login` | Login |
| `/portal` | Portal |
| `/files` | File browser |
| `/video` | Movie center |
| `/video/:videoId` | Movie or episode detail |
| `/video/series/:seriesId` | Series detail |
| `/video/:videoId/play` | Player |
| `/video/:videoId/metadata` | Metadata editor |
| `/music` | Music center |
| `/reader` | Reader center |
| `/admin/:section` | Admin dashboard sections |

Unauthenticated users are redirected to `/login?redirect=<target>`.

## API Integration

Feature APIs live close to their modules:

```text
lib/features/files/data/file_api.dart
lib/features/video/data/movie_api.dart
lib/features/music/data/music_api.dart
lib/features/reader/data/reader_api.dart
lib/features/admin/data/
```

Shared network behavior lives in:

```text
lib/core/network/api_client.dart
lib/core/network/auth_interceptor.dart
lib/core/network/retry_interceptor.dart
```

## Development Notes

- Keep business state in Riverpod controllers under each feature's `application/` directory.
- Keep DTO and domain parsing close to each feature.
- Put cross-feature widgets in `lib/core/widgets` only when they are genuinely reusable.
- Platform-specific behavior should go through `lib/platform` rather than direct platform checks in feature pages.
- Match existing module styles before adding new UI patterns.
- Add focused tests for auth, network, controllers, and high-risk parsing logic.
