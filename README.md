# Mental Health App

Flutter application for mental health support features such as authentication, chat, voice input, notifications, file and media access, reports, and external service integration.

## What you need

Install these before running the project:

1. Flutter SDK 3.9.2 or newer, with Dart 3.9.x.
1. Git.
1. An editor such as VS Code or Android Studio.
1. For Android: Android SDK, Android Studio, and either an emulator or a physical device.
1. For iOS: Xcode on macOS with a simulator or physical device.
1. For web: Google Chrome.
1. Internet access, because the app talks to a remote backend API.

## Project dependencies

The app uses these Flutter packages at runtime:

- cupertino_icons
- image_picker
- shared_preferences
- dio
- flutter_secure_storage
- google_sign_in
- record
- path_provider
- permission_handler
- http
- http_parser
- audioplayers
- url_launcher
- pdf
- printing
- open_filex
- flutter_local_notifications
- timezone
- flutter_timezone
- shimmer

Development-only packages:

- flutter_test
- flutter_lints
- flutter_launcher_icons

The app also depends on these services and platform integrations:

- Backend API: https://fyp-mental-health-therapist-fastapi.onrender.com
- Android permissions for RECORD_AUDIO, INTERNET, CALL_PHONE, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, and VIBRATE
- Voice features that call OpenAI speech transcription and Azure speech text-to-speech services

## Step-by-step: run the project

### 1. Open the project folder

Open the folder c:\FYP\Project_Code\mental_health_app in VS Code or Android Studio.

### 2. Check Flutter is installed

Run:

```bash
flutter --version
```

If Flutter is not installed, install the Flutter SDK first and make sure flutter is available in your terminal.

### 3. Get the dependencies

From the project root, run:

```bash
flutter pub get
```

This downloads every package listed in pubspec.yaml and prepares the app to build.

### 4. Verify your target device

Choose one target:

- Android emulator
- Android physical device with USB debugging enabled
- iOS simulator or iPhone device on macOS
- Chrome for web

Check available devices with:

```bash
flutter devices
```

### 5. Make sure the backend is reachable

The app is configured to use the remote API at https://fyp-mental-health-therapist-fastapi.onrender.com.

Before launching the app, confirm:

- You have an internet connection.
- The backend server is online.
- Your account or session tokens are valid if you are testing authenticated screens.

### 6. Run the app

Use the target you want:

```bash
flutter run
```

If multiple devices are connected, pick one explicitly:

```bash
flutter run -d <device_id>
```

You can get the device id from flutter devices.

### 7. Grant permissions when prompted

The app may ask for permissions during use. Allow the ones needed for the feature you are testing:

- Microphone access for voice recording
- Notification permission for reminders and alerts
- Phone permission for call actions
- File and media access for uploads and picking files

### 8. If you want a clean rebuild

If the app was already built before and you want to reset generated files, run:

```bash
flutter clean
flutter pub get
flutter run
```

## Platform notes

### Android

- Use Android Studio or another installed Android SDK setup.
- The manifest already declares the needed permissions for audio, notifications, calls, internet, and reboot scheduling.
- If you test notifications, allow them on the device when Android asks.

### iOS

- Build on macOS with Xcode installed.
- Open the iOS simulator or sign the app for a physical device if needed.

### Web

- Run the app in Chrome with:

```bash
flutter run -d chrome
```

## Common issues

- If flutter pub get fails, check your network and Flutter installation.
- If the app opens but features fail, confirm the backend API is online.
- If microphone or notification features do nothing, make sure you accepted the device permission prompts.
- If Google sign-in or voice features fail, check that the device has internet access and the relevant platform services are available.

## Helpful commands

```bash
flutter doctor
flutter devices
flutter pub get
flutter run
flutter clean
```
