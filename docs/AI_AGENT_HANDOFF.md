# AI Agent Handoff: Book App Themed (Cupertino Flutter)

This document is for future AI agents working on this repository.

It summarizes what is currently implemented, how the app is structured, and the constraints already established by the user.

## Project Summary

- App type: Flutter app (Android-targeted build via GitHub Actions)
- Design language: Cupertino (iOS-style), explicitly **not** Material Design
- App name (branding): `BlackPirateX Book tracker`
- Android package / applicationId target: `com.blackpiratex.book` (patched in CI after Android scaffold generation)
- Local environment note: this repo may be edited on a weak machine without Flutter installed; CI is used for build/analyze
- Android platform files are **not** stored in repo; CI generates them with `flutter create --platforms=android .`
- Firebase Android config: root `google-services.json` is copied into generated `android/app/` during CI before build

## Current Architecture (Modular)

Main entry and app shell:
- `lib/main.dart`: bootstraps app, initializes storage-backed controller
- `lib/app.dart`: `CupertinoApp` wrapper, listens to `AppController` for theme updates and routes users through auth gate -> onboarding -> home

Domain model:
- `lib/models/book.dart`
  - `BookItem`
  - `BookDraft`
  - `BookStatus` (`Reading`, `Read`, `Reading List`, `Abandoned`)
  - `ReadingMedium` (`Kindle`, `Paperback`, `Mobile`, `Laptop`)

State and persistence:
- `lib/state/app_controller.dart`: app state, filtering, CRUD, dark mode, auth session state, backend-mode switching (guest legacy API vs account v1 API), persistence orchestration
- `lib/services/app_storage_service.dart`: `shared_preferences` load/save (books, settings, backend config/token, onboarding, frontend auth session)
- `lib/services/backend_api_service.dart`: backend HTTP client for both legacy (`/api/public`, `/api/books`) and account v1 (`/api/v1/*`) APIs, including v1 cover upload
- `lib/services/firebase_auth_service.dart`: Firebase Auth email/password signup/login, email verification send, and ID token retrieval
- `lib/services/book_discovery_service.dart`: direct OpenLibrary + Google Books search (local add flow)
- `lib/services/local_media_service.dart`: device image picker + local cover file storage
- `lib/services/local_backup_service.dart`: zip import/export of local app data + local cover image files

Pages:
- `lib/pages/auth_gate_page.dart` (auth gate after onboarding; Firebase email/password auth + hidden guest mode trigger)
- `lib/pages/first_run_intro_page.dart` (first-open onboarding / intro tutorial)
- `lib/pages/home_page.dart`
- `lib/pages/book_details_page.dart`
- `lib/pages/book_editor_page.dart`
- `lib/pages/book_search_page.dart` (backend search + add to Reading List)
- `lib/pages/direct_book_search_page.dart` (OpenLibrary + Google Books direct search + local add)
- `lib/pages/stats_page.dart` (local-cache stats + charts)
- `lib/pages/settings_page.dart`

Shared widgets:
- `lib/widgets/brand_app_icon.dart`
- `lib/widgets/book_card.dart`
- `lib/widgets/book_cover.dart`
- `lib/widgets/floating_status_bar.dart`
- `lib/widgets/section_card.dart`

Utilities:
- `lib/utils/date_formatters.dart`

Planning / build specs:
- `docs/API_AGENT_BACKEND_BUILD_SPEC.md` (future backend implementation spec for AI agents; Firebase Auth + Turso + full sync scope)

## Features Currently Implemented

### 1. Cupertino-Only Themed App

- Uses `CupertinoApp` and Cupertino widgets
- No Material UI components are intentionally used
- User requested Cupertino styling and avoidance of Android Material design
- `CupertinoApp.title` is set to `BlackPirateX Book tracker`

### 2. Home Page (Books Shelf)

Implemented in `lib/pages/home_page.dart`.

Features:
- Large `My Books` heading
- Branded SVG app icon shown in header (`assets/icons/blackpiratex_book_tracker_icon.svg`)
- Small brand label text (`BlackPirateX Book tracker`) under the heading
- Top-right action buttons:
  - Settings button
  - Abandoned shelf quick-access button (next to Settings)
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
- Extra action:
  - `Stats` (opens local-cache stats page)

Note:
- `Abandoned` is intentionally not part of the floating bottom shelf bar; it is accessed from the dedicated header icon button.

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
- Loads `coverUrl` via `CachedNetworkImage`
- Disk-caches remote cover images for reuse across launches
- Loading indicator while fetching image
- Error fallback if URL fails
- Default generated cover placeholder with gradient + book icon + title text
- Hero animation support via `heroTag`

### Branding Assets / App Icon

- SVG source icon lives at `assets/icons/blackpiratex_book_tracker_icon.svg`
- Flutter UI uses the SVG through `flutter_svg` (`lib/widgets/brand_app_icon.dart`)
- Android launcher icons are generated from the SVG in CI using `rsvg-convert` after `flutter create`

### 6. Book Details Page

Implemented in `lib/pages/book_details_page.dart`.

Features:
- Top navigation with back button (Cupertino nav bar)
- `Edit` button in nav bar
- Large hero cover image
- Title and author display
- Colored status badge row (replaced old Actions section)
  - When status is `Reading`, this row shows a reading progress card with progress bar + percentage
  - Otherwise shows status badge
- Side delete button in same row (per user request)
- "More Details" section displayed as a 2-column grid with higher-contrast colorful icon/label accents (Cupertino-styled)
- "Description" section (renamed from Notes in details page UI)
- Highlights section redesigned for readability
  - Quick `Add` highlight button (Cupertino sheet composer)
  - Per-highlight `Copy` button
  - Saves locally and syncs highlights to backend via `/api/books` `POST` `action: "update"` (`highlights`, `hasHighlights`)
- Highlight add composer shifts above keyboard (keyboard-safe bottom sheet padding)
- When status is `Reading`, a glassy floating quick-actions bar appears at bottom
  - Quick Highlight (local-only)
  - Quick Progress adjuster (local-only)
  - These quick actions intentionally do not sync immediately; local cache changes persist until manual refresh/overwrite
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
  - Cover image upload from device (stored locally in app documents dir)
  - Page count
  - Notes
- Reading status selector:
  - Reading
  - Read
  - Reading List
  - Abandoned
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

Important backend note:
- API docs do not currently expose a cover image file upload endpoint, so device-uploaded cover images remain local-only and are not sent to backend APIs.

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
  - `Search OpenLibrary + Google Books`
  - `Add Manually`
- Backend search uses `/api/search`
- Search results show an `Add to Reading List` button per result
- Adding via search uses `/api/books` `POST` with `action: "add"` and `shelf: "watchlist"`
- Search/add flows show loading/status messages because responses may take time
- Successful add inserts/updates the local cached list immediately and switches shelf to `Reading List`
- Direct search (OpenLibrary + Google Books) adds books locally only (guest/local mode friendly) and preserves remote cover URLs from those APIs on the local book record

### 9. Home Pull-To-Refresh (Backend Diff Sync)

Implemented in:
- `lib/pages/home_page.dart`
- `lib/state/app_controller.dart`

Behavior:
- Home list supports pull-to-refresh (`CupertinoSliverRefreshControl`)
- Pull refresh fetches `/api/books` and compares against local cached books
- Only applies and saves the fetched payload if backend data changed
- If no changes are found, local cache remains untouched and a sync status message is updated
- Pull refresh is the primary manual way to refresh backend data from the home screen
### 10. Settings Page

Implemented in `lib/pages/settings_page.dart`.

Features:
- Account section clarifies auth/local mode behavior
  - Guest mode is the local mode
- Dark mode toggle (real setting, persisted)
- Account section (auth status)
  - Shows `Logged in`, `Guest`, or `Signed out`
  - Displays saved frontend auth name/email when present
  - Shows `Log Out` button when logged in with an account
- Backend section (wired)
  - Backend API URL field (persisted)
  - Credential dialog / local credential storage (legacy admin password OR Firebase ID token for v1)
  - `Test Connection` button
  - `Force Reload From API` button
  - Backend cache / local changes / last sync status rows
  - Confirmation dialog before force reload if local changes exist
  - In logged-in mode, backend URL is fixed to `https://book-tracker-backend-inky.vercel.app`
  - In logged-in mode, legacy backend search/add endpoints are unavailable and user is directed to direct search/manual add flows
- Local Data (Guest Mode) section
  - Export local backup to zip (written to app storage, then opens OS share sheet on mobile)
  - Import local backup from zip (replaces local data)
  - Backup includes books, local settings/session UI state, backend config, and local cover image files

### 11. Dark Mode

Implemented via `AppController` and `shared_preferences`.

### 12. Auth Gate (Firebase + Guest)

Implemented in:
- `lib/pages/auth_gate_page.dart`
- `lib/app.dart`
- `lib/state/app_controller.dart`
- `lib/services/app_storage_service.dart`
- `lib/services/firebase_auth_service.dart`

Behavior:
- On first install/open, the app now shows a Cupertino auth screen before onboarding/home
- Users can choose:
  - `Sign Up` (Firebase email/password)
  - `Log In` (Firebase email/password)
  - `Continue as Guest` (local mode)
- Signup/login use Firebase Auth and then call backend `GET /api/v1/me` to bootstrap account session
- Signup sends a Firebase email verification email for unverified users
- Hidden guest mode trigger: long-press the app icon on the auth gate (visible guest button removed)
- Selected auth session is persisted locally so the auth gate is skipped on later launches until logout
- Existing onboarding still appears after auth if it has not been completed yet
- Logged-in mode stores the Firebase ID token in the existing backend credential field for compatibility, and refreshes token from Firebase before v1 API calls when possible

### 14. Dual Backend Routing (Guest Legacy API vs Logged-in v1 API)

Behavior:
- Guest mode continues using the legacy backend (`notes.blackpiratex.com`) and legacy endpoints
- Logged-in mode uses the new v1 backend at `https://book-tracker-backend-inky.vercel.app`
- Logged-in mode backend sync uses Firebase Auth ID tokens from the app (manual token paste remains a fallback)
- On login/signup, the app attempts an immediate backend fetch to load account books right away
- Logged-in mode supports:
  - full book fetch via `/api/v1/books`
  - book upsert via `PUT /api/v1/books/:id`
  - delete via `DELETE /api/v1/books/:id`
  - cover upload for locally picked images via `/api/v1/uploads/cover`
- Legacy backend search (`/api/search`) is guest-only; account mode should use direct OpenLibrary/Google Books search

### 13. Local Backup Import/Export (Books + Settings + Local Cover Files)

Implemented in:
- `lib/services/local_backup_service.dart`
- `lib/state/app_controller.dart`
- `lib/pages/settings_page.dart`

Behavior:
- Export creates a zip backup containing a manifest snapshot of local app data and bundled local cover image files
- Export writes the zip to app documents storage (`exports/`) and then attempts to open the mobile OS share sheet (instead of relying on a save-file picker)
- Import restores local app data and extracts local cover files, rewriting book cover file paths to the current device app storage directory
- Intended primarily for guest/local mode portability and device migration

### 15. Android CI Build (Generated Platform + Firebase)

Behavior:
- GitHub Actions generates `android/` with `flutter create`
- CI copies repository-root `google-services.json` into `android/app/google-services.json`
- `scripts/configure_generated_android.py` patches generated Gradle files to apply the Google Services plugin for Firebase

### 16. Recent UX / Sync Behavior Tweaks

Behavior:
- Onboarding is shown before the auth gate on first launch
- Guest mode no longer uses home pull-to-refresh for legacy backend; guest legacy reload is intended via Settings -> Force Reload From API
- Guest mode legacy write push helpers are disabled (local edits stay local unless user uses explicit backend actions)
- Direct-source search results now provide three add buttons: `Read`, `Reading`, and `Watchlist`
- Settings hides advanced backend controls by default; tapping app version 3 times reveals/hides them
- Theme now follows device light/dark mode automatically (no manual dark-mode switch in settings)

## Agent Workflow Expectation

- When making meaningful product/code changes, update `docs/AI_AGENT_HANDOFF.md` in the same change set so future agents inherit current behavior and architecture.
- When shipping changes intended for users, bump the app version in `pubspec.yaml` (`version:`) in the same change set.

Features:
- Toggle from settings page
- Persists across app launches
- `CupertinoApp` theme updates reactively via `AnimatedBuilder`

### 12. Local Persistence (Books + Theme + Backend Sync Metadata)

Implemented in `lib/services/app_storage_service.dart`.

Stored using `shared_preferences`:
- Books list
- Dark mode flag
- First-run onboarding completion flag
- Backend API URL
- Backend password
- Backend cache primed flag
- Local book changes (dirty) flag
- Last backend sync timestamp

Keys:
- Books (current): `book_items_v2`
- Books (legacy read fallback): `book_items_v1`
- Dark mode: `dark_mode_enabled_v1`
- First-run onboarding seen: `has_seen_onboarding_v1`
- Backend API URL: `backend_api_url_v1`
- Backend password: `backend_password_v1`
- Backend cache primed: `backend_cache_primed_v1`
- Local changes flag: `backend_local_book_changes_v1`
- Last backend sync: `backend_last_sync_at_v1`

Backward compatibility:
- Loader attempts `book_items_v2`, then falls back to `book_items_v1`
- Legacy `isRead` boolean is mapped into new `BookStatus`

### 13. Book Status and Filtering Model

Implemented in `lib/models/book.dart` and `lib/state/app_controller.dart`.

Status model is now 4-state:
- `reading`
- `read`
- `reading_list`
- `abandoned`

Filtering behavior:
- Home page shows books only for selected shelf
- Shelf selection is stored in controller runtime state (not currently persisted)

### 13.5 First-Run Onboarding / Intro Tutorial

Implemented in:
- `lib/pages/first_run_intro_page.dart`
- `lib/app.dart`
- `lib/state/app_controller.dart`
- `lib/services/app_storage_service.dart`

Behavior:
- On the very first open after install (before onboarding flag is saved), app shows a swipeable Cupertino intro/tutorial instead of Home.
- Tutorial explains:
  - shelves + bottom shelf bar
  - add flow (manual vs API search)
  - details/progress/highlights/edit flow
  - backend refresh, stats, and settings
- `Skip` and `Get Started` both mark onboarding as seen and persist it via `shared_preferences`.
- After completion, app rebuilds into the normal `HomePage`.

### 14. Backend Sync + Caching Behavior

Implemented in:
- `lib/services/backend_api_service.dart`
- `lib/state/app_controller.dart`

Behavior:
- Reads from backend using `GET /api/books` (see `docs/API_DOCS.md`)
- Maps backend row schema into local `BookItem` model
- Preserves backend `abandoned` shelf mapping (no longer downgrades it to another local shelf)
- Maps backend highlights into local `BookItem.highlights`
- Can push highlight-only updates to backend using `/api/books` `POST` `action: "update"` with `highlights` + `hasHighlights`
- Caches fetched books locally in existing books storage key
- First install / first app open:
  - app uses prefilled backend URL (`https://notes.blackpiratex.com`) as the default controller backend URL

### 15. Stats Page (Local Cache Only)

Implemented in:
- `lib/pages/stats_page.dart`
- `lib/pages/home_page.dart`

Behavior:
- Uses only `AppController.books` (local cache / local state), no API calls
- Counts only finished books:
  - local status must be `Read`
  - `endDateIso` must be set/parseable
- Uses `endDateIso` year for yearly grouping
- Default year selection is current year if available, otherwise latest available year
- Shows selected-year summary:
  - finished books count
  - total pages read
  - top authors
  - finished books cover grid
- Yearly book cover grid items are tappable and open `BookDetailsPage`
- Always shows trend charts:
  - books read over years
  - pages read over years
- Shows reading medium distribution chart for finished books
  - auto-fetches from backend on first launch if cache is not primed
- Auto-fetches on app startup only when:
  - backend API URL is configured
  - backend cache is not yet primed
  - there are no local book changes
- Does **not** auto-fetch on subsequent opens once cache is primed
- Local add/edit/delete marks the cache as having local changes (dirty), which pauses auto-refresh
- User can always override via Settings -> `Force Reload From API`
- Editing an existing backend-backed book (OpenLibrary `OL...` id) attempts immediate remote sync via `/api/books` `POST` `action:"update"` after local save
- If backend edit sync fails, the local edit is kept and the cache is marked dirty

Important:
- Current implementation is mostly local-first, with selective backend writes:
  - backend search add (`action:"add"`) is wired
  - backend edit update (`action:"update"`) is wired for backend-backed books (`OL...` ids)
  - local-only/manual books are not automatically created/updated on backend

### 15. CI: Android APK Build in GitHub Actions

Workflow:
- `.github/workflows/android-build.yml`

Behavior:
- Checks out repo
- Installs Java 17
- Installs Flutter (stable)
- Generates Android scaffold in CI:
  - `flutter create --platforms=android ... .`
- Patches generated Android scaffold to enforce:
  - package/applicationId `com.blackpiratex.book`
  - app label `BlackPirateX Book tracker`
  - `INTERNET` permission
  - `MainActivity` package path/namespace alignment
  - release signing config injection (so CI uses repo keystore secrets instead of default debug signing)
- Renders Android launcher icons from the SVG app icon source using `librsvg2-bin` (`rsvg-convert`)
- Validates required signing secrets are present, decodes the release keystore into `android/app/ci-release.jks`, and verifies alias/password with `keytool`
- Runs:
  - `flutter pub get`
  - `flutter analyze`
  - `flutter build apk --release`
- Uploads APK artifact

Required GitHub Secrets for signed release APKs:
- `ANDROID_KEYSTORE_BASE64` (base64-encoded `.jks`)
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Signing implementation notes:
- Android platform files are regenerated on every CI run, so signing config is patched into the generated `android/app/build.gradle(.kts)` by `scripts/configure_generated_android.py`.
- Workflow includes debug steps that print:
  - keystore file presence/size
  - `keytool` alias listing (first lines only)
  - generated Gradle signing section
  - signing-related Gradle lines on failure
- Do not rotate the keystore/alias for updates unless intentionally changing app signing strategy (users will not be able to update otherwise).

Note:
- Legacy Gradle workflow for the previous non-Flutter app was removed.

## UI / UX Adjustments Already Requested and Implemented

These changes were specifically requested by the user and are already applied:

- Larger `My Books` heading
- Larger plus button on home page
- Bottom floating blurred shelf selector (instead of top segmented bar)
- Bottom floating shelf selector restyled to dark segmented capsule (Apple Fitness-style visual direction)
- Bottom floating shelf selector now adapts visually for both light and dark themes (same segmented capsule style)
- Read shelf titles are no longer struck through in book cards
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
- `BookSearchPage` async flows should avoid `return` inside `finally`; use `if (mounted) { setState(...) }` guards instead (CI flags `control_flow_in_finally`).
- Because Android platform files are generated in CI (`flutter create`), the CI workflow now patches `android/app/src/main/AndroidManifest.xml` to add `INTERNET` permission so release APKs can access backend APIs and cover images.
- Because Android platform files are generated in CI (`flutter create`), CI also patches the generated Gradle app module to inject release signing config from environment variables (`ANDROID_KEYSTORE_*`) before `flutter build apk --release`.

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
