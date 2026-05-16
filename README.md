# Load Vehicle Connect

A feature-first, scalable Flutter architecture for vehicle tracking and load management.

## Project Structure

- `android/`, `ios/`: Native code.
- `assets/`: Images, icons, fonts, and animations.
- `lib/`:
  - `app/`: Root MaterialApp, Routing, and Theme.
  - `core/`: Constants, config, network setup, services, utils, and extensions.
  - `data/`: Models and repositories for data handling.
  - `features/`: Module-based feature organization (Splash, Auth, Home, Request, Tracking, etc.).
  - `shared/`: Reusable widgets and global controllers.

## Getting Started

1. Clone the repository.
2. Run `flutter pub get`.
3. Configure Firebase in `lib/core/config/firebase_options.dart`.
4. Run using `flutter run --target lib/main_dev.dart` for dev or `flutter run --target lib/main_prod.dart` for prod.
