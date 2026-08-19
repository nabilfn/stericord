# Mobile platform folders

`android/` and `ios/` are intentionally not hand-written — they're generated,
native-toolchain-specific projects that `flutter create` produces correctly
for the installed Flutter/Xcode/Android SDK versions. Hand-authoring them
risks a broken or stale native project.

Once the Flutter SDK is installed locally, run from `apps/mobile/`:

```bash
flutter create --org com.stericord --platforms=android,ios .
```

This only adds the `android/` and `ios/` folders; it does not touch the
existing `lib/`, `pubspec.yaml`, or `test/` in this project (matching the
[official guidance](https://docs.flutter.dev/reference/create-new-app) for
adding platforms to an existing app).

Then:

```bash
cp .env.example .env   # fill in SUPABASE_URL / SUPABASE_ANON_KEY from `supabase status`
flutter pub get
flutter run
```
