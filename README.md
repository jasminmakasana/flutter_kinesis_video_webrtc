<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

## Usage

```dart
peerConnection() async {
  SignalingClient _signalingClient = SignalingClient(
    channelName: 'YOUR_AWS_ACCESS_KEY',
    accessKey: 'YOUR_AWS_SECRET_KEY',
    secretKey: 'YOUR_REGION',
    region: 'YOUR_CHANNEL_NAME',
  );

  await _signalingClient.init();
}
```

### iOS

Add the following entry to your _Info.plist_ file, located
in `<project root>/ios/Runner/Info.plist`:

```xmls
<key>NSCameraUsageDescription</key>
<string>$(PRODUCT_NAME) Camera Usage!</string>
<key>NSMicrophoneUsageDescription</key>
<string>$(PRODUCT_NAME) Microphone Usage!</string>
```

This entry allows your app to access camera and microphone.

### Android

Ensure the following permission is present in your Android Manifest file, located
in `<project root>/android/app/src/main/AndroidManifest.xml`:

```xmls
<uses-feature android:name="android.hardware.camera" />
<uses-feature android:name="android.hardware.camera.autofocus" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.CHANGE_NETWORK_STATE" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

If you need to use a Bluetooth device, please add:

```xmls
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
```

If necessary, in the same `build.gradle` you will need to increase `minSdkVersion`
of `defaultConfig` up to `23` (currently default Flutter generator set it to `16`).
