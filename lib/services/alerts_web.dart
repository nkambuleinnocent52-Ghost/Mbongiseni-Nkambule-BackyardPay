import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> enableAlerts() async {
  if (!web.window.isSecureContext)
    return 'Browser alerts need an HTTPS connection. In-app notifications still work.';
  try {
    final permission =
        (await web.Notification.requestPermission().toDart).toDart;
    return permission == 'granted'
        ? 'Browser alerts enabled while BackyardPay is open.'
        : 'Browser alerts were not allowed. You can still read all alerts in Notifications.';
  } catch (_) {
    return 'This browser does not support alerts. In-app notifications still work.';
  }
}

void showAlert(String title, String message) {
  try {
    if (web.Notification.permission == 'granted') {
      web.Notification(title, web.NotificationOptions(body: message));
    }
  } catch (_) {
    /* In-app records remain available when browser alerts are unavailable. */
  }
}
