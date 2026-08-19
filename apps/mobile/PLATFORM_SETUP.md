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

## Camera permission (required for QR scanning, Phase 3+)

`flutter create` does not add camera permission entries, and `mobile_scanner`
needs one on each platform or the OT point-of-use scan screen will crash/
black-screen at runtime:

- **Android** (`android/app/src/main/AndroidManifest.xml`): add
  `<uses-permission android:name="android.permission.CAMERA" />` above the
  `<application>` tag.
- **iOS** (`ios/Runner/Info.plist`): add an `NSCameraUsageDescription` key
  with a user-facing string, e.g. "SteriCord needs the camera to scan
  instrument pack QR codes."

See the [mobile_scanner installation docs](https://pub.dev/packages/mobile_scanner#installation) for the current specifics.
