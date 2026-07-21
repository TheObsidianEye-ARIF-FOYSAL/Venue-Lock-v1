import 'dart:html' as html;

/// True when the web build is running on a phone-class browser (or a
/// narrow/installed-PWA viewport), as opposed to a desktop/laptop browser.
bool isMobileWebBrowser() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  final isMobileUa = RegExp(
    r'android|iphone|ipad|ipod|mobile|windows phone',
  ).hasMatch(ua);

  final width = html.window.screen?.width;
  final isNarrowViewport = width != null && width < 900;

  return isMobileUa || isNarrowViewport;
}
