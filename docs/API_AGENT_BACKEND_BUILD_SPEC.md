# AI Agent API Build Spec (Firebase Auth + Turso) for Book App Themed

This document tells a future AI agent how to build the backend API for this app.

It is a forward-looking implementation spec (not the current backend state).

## Goal

Build a backend that syncs the app's currently local-first features to a user account:

- Firebase Authentication for user identity
- Turso (LibSQL/SQLite) for storage
- File/object storage for uploaded cover images and backups (provider can vary)
- API that supports full sync of user data created in the Flutter app

## What Must Sync (From Current App Features)

All user-content features currently stored locally should be syncable:

- Books CRUD
- Shelf/status (`Reading`, `Read`, `Reading List`, `Abandoned`)
- Progress, rating, page count, medium
- Notes/description
- Start/end dates
- Highlights list
- Cover image URL and uploaded device cover images (server-hosted URL after upload)
- Auth/account session data relevant to user profile (display name/email from Firebase profile)
- Local backup/import/export equivalent at account scope (server backup import/export endpoints)

Device-only settings should remain local and not sync unless explicitly requested:

- Dark mode preference (optional future sync)
- Backend base URL (dev setting)
- Cached sync status flags

## Required Stack

- Runtime: Node.js + TypeScript (recommended) or another server runtime if equivalent
- Auth: Firebase Authentication
- DB: Turso (LibSQL)
- Migrations: SQL migrations checked into repo
- Storage:
  - Cover uploads: S3-compatible storage / Cloud Storage / R2 (any provider)
  - Backup archives (optional but recommended) can use same storage

## Auth Model (Firebase)

### Client Flow

- Flutter client signs in with Firebase Auth (email/password to start)
- Client sends Firebase ID token in `Authorization: Bearer <token>`

### Server Requirements

- Verify Firebase ID token on every authenticated request
- Extract:
  - `uid` (primary user identity)
  - `email`
  - `name` / display name if present
- Upsert user row on first authenticated request

### Guest Mode Mapping

- Guest mode remains local-only in app UX
- No server account/data is created until user authenticates
- Add migration path endpoint for "upload my local data to account" (bulk import/sync)

## Turso Database Schema (Minimum)

Use per-user ownership on all user data rows.

### `users`

- `id` TEXT PK (Firebase `uid`)
- `email` TEXT
- `display_name` TEXT
- `photo_url` TEXT NULL
- `created_at` TEXT (ISO)
- `updated_at` TEXT (ISO)

### `books`

- `id` TEXT PK (client-generated ID allowed)
- `user_id` TEXT NOT NULL (FK to `users.id`)
- `title` TEXT NOT NULL
- `author` TEXT NOT NULL DEFAULT ''
- `notes` TEXT NOT NULL DEFAULT ''
- `cover_url` TEXT NOT NULL DEFAULT ''
- `cover_storage_key` TEXT NULL (if uploaded image managed by backend)
- `status` TEXT NOT NULL
- `rating` INTEGER NOT NULL DEFAULT 0
- `page_count` INTEGER NOT NULL DEFAULT 0
- `progress_percent` INTEGER NOT NULL DEFAULT 0
- `medium` TEXT NOT NULL
- `start_date_iso` TEXT NULL
- `end_date_iso` TEXT NULL
- `created_at_iso` TEXT NOT NULL
- `updated_at_iso` TEXT NOT NULL
- `deleted_at_iso` TEXT NULL (soft delete for sync)
- `version` INTEGER NOT NULL DEFAULT 1

Indexes:

- `(user_id, updated_at_iso)`
- `(user_id, status)`
- `(user_id, deleted_at_iso)`

### `book_highlights`

- `id` TEXT PK
- `book_id` TEXT NOT NULL
- `user_id` TEXT NOT NULL
- `position` INTEGER NOT NULL
- `text` TEXT NOT NULL
- `created_at_iso` TEXT NOT NULL
- `updated_at_iso` TEXT NOT NULL

Indexes:

- `(user_id, book_id)`
- `(user_id, updated_at_iso)`

Note:
- Current app stores highlights as a list on the book object. Backend may store normalized rows and return list shape to client.

### `user_preferences` (optional now, recommended)

- `user_id` TEXT PK
- `dark_mode` INTEGER NULL
- `updated_at_iso` TEXT NOT NULL

If not implemented initially, keep dark mode local-only.

### `sync_snapshots` (optional for backup/export)

- `id` TEXT PK
- `user_id` TEXT NOT NULL
- `kind` TEXT NOT NULL (`manual_export`, `import_archive`, etc.)
- `storage_key` TEXT NOT NULL
- `created_at_iso` TEXT NOT NULL

## API Design Principles

- JSON only (except file upload/download endpoints)
- Versioned routes: `/v1/...`
- Auth required for all user data endpoints
- Idempotent writes where possible
- Support offline-first sync:
  - client-generated IDs
  - `updated_at` + `version`
  - conflict response shape
- Keep response models close to Flutter `BookItem`/`BookDraft` shape

## Core API Functions (Must Have)

### 1. Auth Session Bootstrap

`GET /v1/me`

Purpose:
- Verify token
- Return normalized user profile and server capabilities

Response:
- `user`
- `capabilities` (coverUpload, backups, directSearchProxy, etc.)
- `serverTime`

### 2. Full Book List Sync

`GET /v1/books`

Query:
- `includeDeleted=true|false` (default true for sync clients)

Returns:
- All books for user (including metadata + highlights list)

### 3. Incremental Sync

`GET /v1/sync/changes?since=<iso>`

Returns:
- `booksUpserted`
- `bookIdsDeleted`
- `serverNow`

This is preferred for normal sync after initial load.

### 4. Upsert Book

`PUT /v1/books/:id`

Request body:
- Book payload in app shape, including highlights list
- `clientUpdatedAtIso`
- `baseVersion` (optional but recommended)

Behavior:
- Create if missing
- Update if exists and owned by user
- Increment `version`
- Resolve highlights replacement atomically

### 5. Delete Book (Soft Delete)

`DELETE /v1/books/:id`

Behavior:
- Mark `deleted_at_iso`
- Preserve row for sync reconciliation

### 6. Bulk Sync Push (Local Migration / Catch-up)

`POST /v1/sync/push`

Purpose:
- Upload a batch of locally stored books after guest usage or offline changes

Request:
- `books` array
- `strategy` (`upsert`, `serverWins`, `clientWins` for conflicts)

Response:
- Applied counts + conflict list

### 7. Bulk Sync Pull Snapshot

`GET /v1/sync/snapshot`

Returns:
- Full user dataset in app-compatible backup shape

Use cases:
- Restore to device
- Cross-device migration

### 8. Cover Upload (Required for Local Image Feature Sync)

`POST /v1/uploads/covers`

Content type:
- `multipart/form-data`

Fields:
- `file` (image)
- `bookId` (optional)

Response:
- `url` (public/authorized URL)
- `storageKey`
- image metadata

Notes:
- This endpoint is required because current app supports device-local cover upload and those files need a server-hosted equivalent for sync.

### 9. Direct Search Proxy (Optional but Recommended)

`GET /v1/discovery/search?q=...`

Behavior:
- Query OpenLibrary + Google Books
- Normalize results
- Return merged list

Why:
- Prevent API key exposure (if Google Books key is used)
- Consistent result shape and rate limiting

If not implemented:
- Client may continue direct calls, but backend should still accept saved cover URLs.

### 10. Backup Export / Import (Account Scope)

`GET /v1/backups/export`
- Returns signed download URL or streams zip/json export

`POST /v1/backups/import`
- Accepts zip/json export payload and restores/upserts data

Include:
- books
- highlights
- cover assets (if exported archive bundles them)

## API Response Shapes (App-Compatible)

Prefer returning a normalized shape close to this:

```json
{
  "id": "book_123",
  "title": "Atomic Habits",
  "author": "James Clear",
  "notes": "Notes or description",
  "coverUrl": "https://cdn.example.com/covers/book_123.jpg",
  "status": "read",
  "rating": 5,
  "pageCount": 320,
  "progressPercent": 100,
  "medium": "kindle",
  "startDateIso": "2025-01-01",
  "endDateIso": "2025-01-15",
  "createdAtIso": "2025-01-01T10:00:00.000Z",
  "updatedAtIso": "2025-01-15T18:00:00.000Z",
  "deletedAtIso": null,
  "version": 3,
  "highlights": ["..."]
}
```

## Conflict Handling (Important)

The app is local-first. Conflicts will happen.

Minimum strategy:

- Every book row has `updated_at_iso` + `version`
- Client sends `baseVersion` on updates
- If mismatch:
  - return `409 Conflict`
  - include `serverBook`, `clientBook`, `conflictFields`

Recommended v1 shortcut:

- Last-write-wins for most fields
- Replace highlights list as a whole
- Return final server state after write

## Sync Behavior Expected by App

The backend should support these app scenarios:

- User used guest/local mode for weeks, then signs in and uploads all local books
- User has local uploaded cover images and needs them converted to backend-hosted URLs
- User imports a local backup zip and syncs restored books to backend
- User edits books on multiple devices and merges changes
- Pull-to-refresh fetches changed books only when possible

## Suggested Endpoint List (v1)

- `GET /v1/me`
- `GET /v1/books`
- `GET /v1/sync/changes`
- `PUT /v1/books/:id`
- `DELETE /v1/books/:id`
- `POST /v1/sync/push`
- `GET /v1/sync/snapshot`
- `POST /v1/uploads/covers`
- `GET /v1/discovery/search` (recommended)
- `GET /v1/backups/export` (recommended)
- `POST /v1/backups/import` (recommended)

## Firebase + Turso Implementation Notes for AI Agent

### Firebase

- Use Firebase Admin SDK on server
- Cache public keys / rely on Admin SDK verification
- Do not trust client-provided `uid`
- Map all writes to `uid` from verified token

### Turso

- Use parameterized queries only
- Wrap book + highlights updates in a transaction
- Store timestamps as ISO-8601 UTC strings
- Add migrations for every schema change

### Storage

- Generate deterministic object keys (e.g. `users/{uid}/covers/{bookId}/{timestamp}.jpg`)
- Validate image MIME types and size limits
- Optionally generate resized thumbnails

## Security Requirements

- Auth required for all `/v1/*` user data routes
- User-row ownership checks on every query/write
- Rate limit discovery/search and uploads
- Validate payload sizes (notes/highlights can become large)
- Sanitize uploaded filenames (or ignore and generate server keys)

## Non-Goals (Initial Version)

- Social features
- Shared shelves between users
- Real-time collaboration
- Fine-grained highlight diff merge

## Delivery Checklist for Future AI Agent

- Implement migrations and schema
- Implement Firebase token verification middleware
- Implement books + highlights CRUD/sync endpoints
- Implement cover upload endpoint and storage adapter
- Implement export/import endpoints (or at least snapshot export)
- Document env vars and deployment steps
- Add API tests for auth, ownership, sync, conflict, upload
- Update this doc and `docs/AI_AGENT_HANDOFF.md` after backend is built
