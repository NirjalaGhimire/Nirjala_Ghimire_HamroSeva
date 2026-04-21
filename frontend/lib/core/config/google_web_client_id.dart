import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Sign-In **Web application** OAuth client ID.
///
/// Set it in **`assets/.env`** (recommended):
/// ```env
/// GOOGLE_WEB_CLIENT_ID=123456-abc.apps.googleusercontent.com
/// ```
///
/// Optional override for CI/scripts:
/// `flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=...`
///
/// See **docs/GOOGLE_SIGN_IN_SETUP.md**.

const String _fromCompileTime = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

/// Last resort if `.env` is empty (local hack; prefer editing `assets/.env`).
const String kDefaultGoogleWebClientId = '';

String get googleWebClientId {
  if (_fromCompileTime.isNotEmpty) return _fromCompileTime;
  final fromFile = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';
  if (fromFile.isNotEmpty) return fromFile;
  return kDefaultGoogleWebClientId;
}
