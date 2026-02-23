# Book App Themed

Cupertino-themed Flutter book tracker (Android-targeted UI using Cupertino widgets only; no Material UI components).

## Features

- Add books (title, author, notes)
- Mark read/unread
- 1-5 star rating
- Filter by `All`, `Unread`, `Read`
- Local persistence using `shared_preferences`

## Notes

- This repo intentionally keeps the Flutter app source lightweight.
- GitHub Actions generates the Android platform scaffolding (`flutter create --platforms=android .`) before building.
- If you want to run it locally, install Flutter and run:

```bash
flutter create --platforms=android .
flutter pub get
flutter run
```

