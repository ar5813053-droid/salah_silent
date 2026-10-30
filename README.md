# Salah Silent

Automatic prayer-time silent mode application for Android.

## Milestone 0 – Bootstrap

This is the initial project structure.

### Features in this milestone
- Flutter project with Deep Navy + Soft Gold theme
- Bottom navigation (Home, Schedule, Calls, Settings)
- MethodChannel bridge to Kotlin
- Centralized `SilentSessionManager` stub
- BootReceiver, AlarmReceiver, CallNotificationListener stubs
- GitHub Actions workflow that builds a debug APK

### Build via GitHub Actions
1. Push this repository to GitHub
2. Go to the **Actions** tab
3. Download the `salah-silent-debug-apk` artifact
4. Install the APK on your POCO X3 Pro

### Local development (Termux)
```bash
cd salah_silent
flutter pub get
# Editing is done on device; builds happen on GitHub Actions
```

### Next milestones
- Milestone 1: Prayer Schedule + SQLite
- Milestone 2: Exact Alarm scheduling + Boot recovery
- Milestone 3: Silent mode core (SilentSessionManager full implementation)
- Milestone 4: Permission guided setup
- Milestone 5: Call notification tracking
- Milestone 6: Polish & edge cases
