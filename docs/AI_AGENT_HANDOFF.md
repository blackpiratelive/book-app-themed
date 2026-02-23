# AI Agent Handoff: Book App Themed (Cupertino Flutter)

This document is for future AI agents working on this repository.

It summarizes what is currently implemented, how the app is structured, and the constraints already established by the user.

## Project Summary

- App type: Flutter app (Android-targeted build via GitHub Actions)
- Design language: Cupertino (iOS-style), explicitly **not** Material Design
- Local environment note: this repo may be edited on a weak machine without Flutter installed; CI is used for build/analyze
- Android platform files are **not** stored in repo; CI generates them with `flutter create --platforms=android .`

## Current Architecture (Modular)

Main entry and app shell:
- `lib/main.dart`: bootstraps app, initializes storage-backed controller
- `lib/app.dart`: `CupertinoApp` wrapper, listens to `AppController` for theme updates

Domain model:
- `lib/models/book.dart`
  - `BookItem`
  - `BookDraft`
  - `BookStatus` (`Reading`, `Read`, `Reading List`)
  - `ReadingMedium` (`Kindle`, `Physical Book`, `Mobile`, `Laptop`)

State and persistence:
- `lib/state/app_controller.dart`: app state, filtering, CRUD, dark mode, persistence orchestration
- `lib/services/app_storage_service.dart`: `shared_preferences` load/save
- `lib/services/backend_api_service.dart`: backend HTTP client (`/api/public`, `/api/books`) + server-row mapping

Pages:
- `lib/pages/home_page.dart`
- `lib/pages/book_details_page.dart`
- `lib/pages/book_editor_page.dart`
- `lib/pages/book_search_page.dart` (backend search + add to Reading List)
- `lib/pages/settings_page.dart`

Shared widgets:
- `lib/widgets/book_card.dart`
- `lib/widgets/book_cover.dart`
- `lib/widgets/floating_status_bar.dart`
- `lib/widgets/section_card.dart`

Utilities:
- `lib/utils/date_formatters.dart`

## Features Currently Implemented

### 1. Cupertino-Only Themed App

- Uses `CupertinoApp` and Cupertino widgets
- No Material UI components are intentionally used
- User requested Cupertino styling and avoidance of Android Material design

### 2. Home Page (Books Shelf)

Implemented in `lib/pages/home_page.dart`.

Features:
- Large `My Books` heading
- Top-right action buttons:
  - Settings button
  - Add (`+`) button (larger size per user request)
- Shelf count subtitle (e.g. number of books in currently selected shelf)
- Scrollable list of books
- Empty state for current shelf with contextual label and add button

### 3. Floating Bottom Shelf Selector (Blurred, iOS-style)

Implemented in `lib/widgets/floating_status_bar.dart`.

Features:
- Floating bar anchored near bottom
- Blur effect (`BackdropFilter`)
- Larger touch targets for better UX (custom buttons, not thin segmented control)
- Icon + label per shelf
- Shelf filters:
  - `Reading`
  - `Read`
  - `Reading List`

Note:
- This was changed from a thin segmented control after UX feedback.

### 4. Book Cards on Home Page

Implemented in `lib/widgets/book_card.dart`.

Features:
- Tap card to open book details page
- Cover image thumbnail
- Fallback/default cover if no image URL or image fails
- Title + author
- Status/progress/medium chips
- Rating chip (only shown when rating > 0)
- Chevron affordance

### 5. Cover Images + Default Cover

Implemented in `lib/widgets/book_cover.dart`.

Features:
- Loads `coverUrl` via `Image.network`
- Loading indicator while fetching image
- Error fallback if URL fails
- Default generated cover placeholder with gradient + book icon + title text
- Hero animation support via `heroTag`

### 6. Book Details Page

Implemented in `lib/pages/book_details_page.dart`.

Features:
- Top navigation with back button (Cupertino nav bar)
- `Edit` button in nav bar
- Large hero cover image
- Title and author display
- Colored status badge row (replaced old Actions section)
  - Distinct visual colors for:
    - Read
    - Reading
    - Reading List
- Side delete button in same row (per user request)
- "More Details" section with icons for:
  - Medium
  - Reading progress %
  - Page count
  - Start date
  - End date
  - Rating
- Notes section
- Delete confirmation dialog

Note:
- The earlier `Actions` section was intentionally removed after UX feedback.

### 7. Book Editor Page (Add / Edit)

Implemented in `lib/pages/book_editor_page.dart`.

Features:
- Supports both add and edit flows using `BookDraft`
- Fields:
  - Title
  - Author
  - Cover image URL
  - Page count
  - Notes
- Reading status selector:
  - Reading
  - Read
  - Reading List
- Progress slider (`0–100%`)
- Rating selector (`0–5`)
- Reading medium selector chips:
  - Kindle
  - Physical Book
  - Mobile
  - Laptop
- Start date picker (Cupertino modal + `CupertinoDatePicker`)
- End date picker
- Clear date buttons
- Save/Cancel in top navigation bar

Validation behavior:
- Save is enabled when title is non-empty
- Numeric parsing for page count is tolerant (`int.tryParse`, defaults to `0`)

### 8. Add Flow: Manual or Backend Search

Implemented in:
- `lib/pages/home_page.dart`
- `lib/pages/book_search_page.dart`
- `lib/state/app_controller.dart`
- `lib/services/backend_api_service.dart`

Features:
- Tapping the home `+` button now shows an action sheet:
  - `Search Library (API)`
  - `Add Manually`
- Backend search uses `/api/search`
- Search results show an `Add to Reading List` button per result
- Adding via search uses `/api/books` `POST` with `action: "add"` and `shelf: "watchlist"`
- Search/add flows show loading/status messages because responses may take time
- Successful add inserts/updates the local cached list immediately and switches shelf to `Reading List`

### 9. Settings Page

Implemented in `lib/pages/settings_page.dart`.

Features:
- Dark mode toggle (real setting, persisted)
- Backend section (wired)
  - Backend API URL field (persisted)
  - Password dialog / local password storage (persisted in `shared_preferences`)
  - `Test Connection` button
  - `Force Reload From API` button
  - Backend cache / local changes / last sync status rows
  - Confirmation dialog before force reload if local changes exist

### 10. Dark Mode

Implemented via `AppController` and `shared_preferences`.

Features:
- Toggle from settings page
- Persists across app launches
- `CupertinoApp` theme updates reactively via `AnimatedBuilder`

### 11. Local Persistence (Books + Theme + Backend Sync Metadata)

Implemented in `lib/services/app_storage_service.dart`.

Stored using `shared_preferences`:
- Books list
- Dark mode flag
- Backend API URL
- Backend password
- Backend cache primed flag
- Local book changes (dirty) flag
- Last backend sync timestamp

Keys:
- Books (current): `book_items_v2`
- Books (legacy read fallback): `book_items_v1`
- Dark mode: `dark_mode_enabled_v1`
- Backend API URL: `backend_api_url_v1`
- Backend password: `backend_password_v1`
- Backend cache primed: `backend_cache_primed_v1`
- Local changes flag: `backend_local_book_changes_v1`
- Last backend sync: `backend_last_sync_at_v1`

Backward compatibility:
- Loader attempts `book_items_v2`, then falls back to `book_items_v1`
- Legacy `isRead` boolean is mapped into new `BookStatus`

### 12. Book Status and Filtering Model

Implemented in `lib/models/book.dart` and `lib/state/app_controller.dart`.

Status model is now 3-state:
- `reading`
- `read`
- `reading_list`

Filtering behavior:
- Home page shows books only for selected shelf
- Shelf selection is stored in controller runtime state (not currently persisted)

### 13. Backend Read Sync (API -> Local Cache)

Implemented in:
- `lib/services/backend_api_service.dart`
- `lib/state/app_controller.dart`

Behavior:
- Reads from backend using `GET /api/books` (see `docs/API_DOCS.md`)
- Maps backend row schema into local `BookItem` model
- Caches fetched books locally in existing books storage key
- Auto-fetches on app startup only when:
  - backend API URL is configured
  - backend cache is not yet primed
  - there are no local book changes
- Does **not** auto-fetch on subsequent opens once cache is primed
- Local add/edit/delete marks the cache as having local changes (dirty), which pauses auto-refresh
- User can always override via Settings -> `Force Reload From API`

Important:
- Current implementation is read-sync only (pull from backend)
- Local book CRUD is not pushed back to backend yet

Exception:
- Backend search add (`/api/books` `action:add`) is now wired from the app for adding books to the Reading List.

### 14. CI: Android APK Build in GitHub Actions

Workflow:
- `.github/workflows/android-build.yml`

Behavior:
- Checks out repo
- Installs Java 17
- Installs Flutter (stable)
- Generates Android scaffold in CI:
  - `flutter create --platforms=android ... .`
- Runs:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter build apk --release`
- Uploads APK artifact

Note:
- Legacy Gradle workflow for the previous non-Flutter app was removed.

## UI / UX Adjustments Already Requested and Implemented

These changes were specifically requested by the user and are already applied:

- Larger `My Books` heading
- Larger plus button on home page
- Bottom floating blurred shelf selector (instead of top segmented bar)
- Bottom floating shelf selector restyled to dark segmented capsule (Apple Fitness-style visual direction)
- Shelf names changed to:
  - Reading
  - Read
  - Reading List
- Shelf selector made larger / easier to tap with icons
- Nav bar overlap issue fixed (removed `SafeArea(top: false)` on nav-bar pages)
- Book details page actions section removed
- Book status shown as colored badge
- Delete button moved to side of status row
- Settings page backend API + password controls, connection test, and force reload added

## Constraints / Expectations for Future Work

- Keep `flutter analyze` clean; recent backend/settings implementation required a `mounted` guard in async settings actions (`use_build_context_synchronously` lint).

Follow these unless the user explicitly changes direction:

- Keep UI Cupertino-themed; avoid Material widgets/design patterns
- Prefer modular files over a single large file
- CI builds Android; local machine may not have Flutter/Dart installed
- Maintain good touch targets and readable mobile-first layout
- Backend settings are UI-only for now

## Known Gaps / Not Yet Implemented (as of this doc)

- No real backend integration (API/password UI only)
- No cover image upload flow (URL input only)
- No search/sort features
- No persisted shelf selection
- No unit/widget test coverage beyond a basic shell render test

## Quick File Reference for Common Changes

Add new book fields:
- `lib/models/book.dart`
- `lib/pages/book_editor_page.dart`
- `lib/pages/book_details_page.dart`
- `lib/widgets/book_card.dart`
- `lib/services/app_storage_service.dart` (if persistence format changes)

Change theme behavior:
- `lib/state/app_controller.dart`
- `lib/app.dart`
- `lib/pages/settings_page.dart`

Change home screen layout:
- `lib/pages/home_page.dart`
- `lib/widgets/floating_status_bar.dart`
- `lib/widgets/book_card.dart`

## Notes for Future AI Agents

- If CI analyzer fails, prioritize compatibility fixes for Flutter SDK API changes (this repo has already seen changes like `minimumSize` and `withValues(alpha: ...)`).
- Before reintroducing any workflow file, check for duplicates under `.github/workflows/`.
- If editing nav-bar pages, verify content does not render under `CupertinoNavigationBar`.
