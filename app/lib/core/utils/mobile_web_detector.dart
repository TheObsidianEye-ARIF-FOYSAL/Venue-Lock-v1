import 'mobile_web_detector_stub.dart'
    if (dart.library.html) 'mobile_web_detector_web.dart' as impl;

/// True when running as a web build on a phone (installed PWA or mobile
/// browser). Used to skip [DevicePreview] on phones so the web app behaves
/// like a native app there, while still showing the device-picker frame on
/// desktop/laptop browsers.
bool isMobileWebBrowser() => impl.isMobileWebBrowser();
