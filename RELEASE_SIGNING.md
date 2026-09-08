# Life Pilot release signing

The application identifier on Android and iOS is `com.minavi.life_pilot`.

## Android / Google Play

1. Create the upload key once and keep both the keystore and passwords in a password manager and an offline backup:
   `keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Move the keystore to `android/upload-keystore.jks`.
3. Copy `android/upload-key.properties.example` to `android/key.properties` and replace every placeholder.
4. Run `flutter build appbundle --release` to produce the store bundle.

The real properties and keystore files are ignored by Git. A release build now fails with a clear message when signing is missing instead of silently using the debug key. Enable Play App Signing when creating the Google Play app and retain the upload key for future versions.

## iOS / App Store

iOS uses automatic signing. On the Mac, open `ios/Runner.xcworkspace` in Xcode, select Runner → Signing & Capabilities, choose the Apple Developer team, and verify the bundle identifier is `com.minavi.life_pilot`. Create the App Store archive with Product → Archive.

Certificates, provisioning profiles, `.p8` keys, and passwords must never be committed.

## Subscription prerequisites

Before enabling the purchase button, create the monthly Plus subscription in Google Play Console and App Store Connect, then connect purchase and restore handling plus server-side receipt verification to the existing subscription tables. Never grant Plus based only on a client callback.
