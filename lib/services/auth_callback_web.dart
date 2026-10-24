import 'package:web/web.dart' as web;

// One-use confirmation/reset codes must not be exchanged again on refresh.
void clearAuthCallbackUrl() {
  final parameters = Map<String, String>.from(Uri.base.queryParameters)
    ..remove('code')
    ..remove('type')
    ..remove('error')
    ..remove('error_code')
    ..remove('error_description');
  final clean = Uri.base.replace(
    query: Uri(queryParameters: parameters).query,
    fragment: '',
  );
  web.window.history.replaceState(null, '', clean.toString());
}
