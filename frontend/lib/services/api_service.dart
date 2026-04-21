import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform, SocketException;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hamro_sewa_frontend/core/utils/image_upload_compress.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'token_storage.dart';

/// Thrown when the access token is invalid and refresh failed or was not possible.
/// App should clear tokens and redirect to login when this is caught.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'SESSION_EXPIRED';
}

class _TimedCacheEntry<T> {
  _TimedCacheEntry({required this.value, required this.expiresAt});

  final T value;
  final DateTime expiresAt;
}

double _roundCoord(double value) {
  return (value * 1e8).round() / 1e8;
}

class ApiService {
  // Emulator: 10.0.2.2 = host. Physical device: 127.0.0.1 with adb reverse, or set BACKEND_HOST to your PC's IP.
  static String? _apiBase;
  static bool? _isPhysicalDevice;
  static String get apiBase => _apiBase ?? _defaultApiBase;
  static String get _defaultApiBase => Platform.isAndroid
      ? "http://10.0.2.2:8000/api"
      : "http://127.0.0.1:8000/api";

  /// Whether the app is running on a physical device (vs emulator). Set by init().
  static bool get isPhysicalDevice => _isPhysicalDevice ?? false;

  /// Hint to show when connection times out (backend not reachable).
  static String get connectionTimeoutHint {
    if (isPhysicalDevice) {
      return 'Connection timed out. On phone: connect USB → run "adb reverse tcp:8000 tcp:8000" → run backend: python manage.py runserver 0.0.0.0:8000';
    }
    return 'Connection timed out. Run backend: python manage.py runserver 0.0.0.0:8000';
  }

  /// Human-readable hint when the phone cannot reach the PC (e.g. connection refused on 127.0.0.1).
  static String friendlyNetworkError(Object e) {
    final s = e.toString();
    final refused =
        s.contains('Connection refused') || s.contains('connection refused');
    final localhost = s.contains('127.0.0.1') || s.contains('localhost');
    if (refused && (isPhysicalDevice || localhost)) {
      return 'Cannot reach Django. On a real phone, 127.0.0.1 is the phone, not your PC. '
          'USB: adb reverse tcp:8000 tcp:8000, then run: python manage.py runserver 0.0.0.0:8000. '
          'Wi‑Fi: add BACKEND_HOST=YOUR_PC_LAN_IP to assets/.env (same network as the phone).';
    }
    if (s.contains('Failed host lookup') ||
        s.contains('Network is unreachable')) {
      return 'Cannot reach backend. Check Wi‑Fi and BACKEND_HOST in assets/.env.';
    }
    return s
        .replaceFirst('Exception: ', '')
        .replaceFirst('ClientException: ', '');
  }

  static Future<http.Response> _sendMultipartRequest(
    http.MultipartRequest request,
  ) async {
    try {
      final streamed =
          await _httpClient.send(request).timeout(const Duration(seconds: 45));
      return await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw Exception(connectionTimeoutHint);
    } on SocketException catch (e) {
      throw Exception(friendlyNetworkError(e));
    } on http.ClientException catch (e) {
      throw Exception(friendlyNetworkError(e));
    }
  }

  static Future<http.Response> _safeHttp(
      Future<http.Response> requestFuture) async {
    try {
      return await requestFuture.timeout(_timeout);
    } on TimeoutException {
      throw Exception(connectionTimeoutHint);
    } on SocketException catch (e) {
      throw Exception(friendlyNetworkError(e));
    } on http.ClientException catch (e) {
      throw Exception(friendlyNetworkError(e));
    }
  }

  /// Call once before runApp. Uses BACKEND_HOST if set (e.g. --dart-define=BACKEND_HOST=192.168.1.5).
  /// Optional: BACKEND_HOST in assets/.env (same as GOOGLE_WEB_CLIENT_ID).
  /// Otherwise: emulator → 10.0.2.2, physical device → 127.0.0.1 (use adb reverse tcp:8000 tcp:8000).
  static Future<void> init() async {
    const backEndHost = String.fromEnvironment(
      'BACKEND_HOST',
      defaultValue: '',
    );
    if (backEndHost.isNotEmpty) {
      _apiBase = 'http://$backEndHost:8000/api';
      _isPhysicalDevice = true;
      return;
    }
    try {
      final fromEnv = dotenv.env['BACKEND_HOST']?.trim() ?? '';
      if (fromEnv.isNotEmpty) {
        _apiBase = 'http://$fromEnv:8000/api';
        _isPhysicalDevice = true;
        return;
      }
    } catch (_) {}
    if (!Platform.isAndroid) {
      _apiBase = "http://127.0.0.1:8000/api";
      _isPhysicalDevice = false;
      return;
    }
    try {
      final deviceInfo = DeviceInfoPlugin();
      final android = await deviceInfo.androidInfo;
      _isPhysicalDevice = android.isPhysicalDevice;
      if (android.isPhysicalDevice) {
        _apiBase =
            "http://127.0.0.1:8000/api"; // requires: adb reverse tcp:8000 tcp:8000 (phone via USB)
      } else {
        _apiBase = "http://10.0.2.2:8000/api"; // emulator: 10.0.2.2 = host
      }
    } catch (_) {
      _apiBase = _defaultApiBase;
      _isPhysicalDevice = false;
    }
  }

  /// Timeout so login/register don't spin forever if the server is unreachable.
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _listCacheTtl = Duration(seconds: 20);
  static final Map<String, _TimedCacheEntry<List<dynamic>>> _listCache = {};
  static final Map<String, Future<List<dynamic>>> _inflightListRequests = {};
  static const Duration _walletCacheTtl = Duration(seconds: 15);
  static _TimedCacheEntry<Map<String, dynamic>>? _walletCache;
  static Future<Map<String, dynamic>>? _inflightWalletRequest;
  static http.Client _httpClient = http.Client();

  @visibleForTesting
  static void setHttpClient(http.Client client) {
    _httpClient = client;
  }

  @visibleForTesting
  static void setApiBaseForTesting(String baseUrl) {
    _apiBase = baseUrl;
  }

  @visibleForTesting
  static void resetTestState() {
    _apiBase = null;
    _listCache.clear();
    _inflightListRequests.clear();
    _walletCache = null;
    _inflightWalletRequest = null;
  }

  static List<dynamic>? _getCachedList(String key) {
    final entry = _listCache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _listCache.remove(key);
      return null;
    }
    return List<dynamic>.from(entry.value);
  }

  static void _setCachedList(String key, List<dynamic> value, {Duration? ttl}) {
    _listCache[key] = _TimedCacheEntry<List<dynamic>>(
      value: List<dynamic>.from(value),
      expiresAt: DateTime.now().add(ttl ?? _listCacheTtl),
    );
  }

  static Future<List<dynamic>> _cachedListRequest({
    required String key,
    required Future<List<dynamic>> Function() loader,
    Duration? ttl,
  }) async {
    final cached = _getCachedList(key);
    if (cached != null) return cached;

    final inFlight = _inflightListRequests[key];
    if (inFlight != null) {
      final shared = await inFlight;
      return List<dynamic>.from(shared);
    }

    final future = loader();
    _inflightListRequests[key] = future;
    try {
      final loaded = List<dynamic>.from(await future);
      _setCachedList(key, loaded, ttl: ttl);
      return List<dynamic>.from(loaded);
    } finally {
      _inflightListRequests.remove(key);
    }
  }

  static String _tokenScopeForCache(String? token) {
    if (token == null || token.isEmpty) return 'anon';
    return token.substring(0, token.length > 12 ? 12 : token.length);
  }

  static String _bookingsCacheKey(String? token) {
    return 'auth_user_bookings::${_tokenScopeForCache(token)}';
  }

  static Future<List<dynamic>?> peekCachedUserBookings() async {
    final token = await TokenStorage.getAccessToken();
    final cached = _getCachedList(_bookingsCacheKey(token));
    if (cached == null) return null;
    return List<dynamic>.from(cached);
  }

  static Map<String, dynamic>? _getCachedWallet() {
    final entry = _walletCache;
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _walletCache = null;
      return null;
    }
    return Map<String, dynamic>.from(entry.value);
  }

  static void _setCachedWallet(Map<String, dynamic> wallet, {Duration? ttl}) {
    _walletCache = _TimedCacheEntry<Map<String, dynamic>>(
      value: Map<String, dynamic>.from(wallet),
      expiresAt: DateTime.now().add(ttl ?? _walletCacheTtl),
    );
  }

  static bool _looksLikeHtml(String body) {
    final t = body.trim().toLowerCase();
    return t.startsWith('<!') || t.startsWith('<html');
  }

  static MediaType _mediaTypeForImageFileName(String fileName) {
    final l = fileName.toLowerCase();
    if (l.endsWith('.png')) return MediaType('image', 'png');
    if (l.endsWith('.webp')) return MediaType('image', 'webp');
    if (l.endsWith('.gif')) return MediaType('image', 'gif');
    if (l.endsWith('.jpg') || l.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return MediaType('image', 'jpeg');
  }

  static Future<dynamic> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (_looksLikeHtml(res.body)) {
        throw Exception('Server returned an error page. Please log in again.');
      }
      try {
        return jsonDecode(res.body);
      } catch (e) {
        return {"message": "Success", "data": res.body};
      }
    } else {
      if (_looksLikeHtml(res.body)) {
        throw Exception(res.statusCode == 401
            ? 'Session expired. Please log in again.'
            : 'Server error. Please try again or log in again.');
      }
      try {
        final error = jsonDecode(res.body) as Map<String, dynamic>?;
        if (error != null) {
          if (res.statusCode == 413 ||
              error['statusCode'] == 413 ||
              (error['message']
                      ?.toString()
                      .toLowerCase()
                      .contains('too large') ??
                  false)) {
            throw Exception(
              'Image is too large for the server. Try again after updating the app, or pick a smaller photo.',
            );
          }
          final msg = error["message"] as String? ?? error["error"] as String?;
          if (msg != null && msg.isNotEmpty) {
            throw Exception(msg);
          }
          final detail = error["detail"] as String?;
          if (detail != null && detail.isNotEmpty) {
            if (detail.toLowerCase().contains('no active account')) {
              throw Exception(
                'Your account exists but login is not enabled yet. Please verify your email or contact support.',
              );
            }
            throw Exception(detail);
          }
          // Django REST framework often returns {field: [errors]}
          final firstKey = error.keys.isNotEmpty ? error.keys.first : null;
          if (firstKey != null) {
            final val = error[firstKey];
            final text = val is List ? val.join(" ") : val.toString();
            throw Exception("$firstKey: $text");
          }
        }
      } catch (e) {
        if (e is Exception) rethrow;
      }
      throw Exception("Request failed with status: ${res.statusCode}");
    }
  }

  static Exception _friendlyFavoriteSetupException() {
    return Exception(
      'Favorites are not configured on server yet. Ask admin to run backend/create_favorites_tables.sql in Supabase SQL editor.',
    );
  }

  static bool _isFavoriteTableMissingError(Object error) {
    final s = error.toString();
    return s.contains('PGRST205') &&
        (s.contains('seva_favorite_service') ||
            s.contains('seva_favorite_provider'));
  }

  /// Runs an authenticated request. On 401, tries refresh once and retries; if still 401, clears tokens and throws [SessionExpiredException].
  static Future<http.Response> _authenticated(
      Future<http.Response> Function(String? token) run) async {
    String? token = await TokenStorage.getAccessToken();
    http.Response res = await _safeHttp(run(token));
    if (res.statusCode == 401) {
      String? refresh = await TokenStorage.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        try {
          final data = await refreshToken(refresh: refresh);
          final newAccess = data['access'] as String?;
          if (newAccess != null) {
            await TokenStorage.saveTokens(
                accessToken: newAccess, refreshToken: refresh);
            res = await _safeHttp(run(newAccess));
          }
        } catch (_) {}
      }
      if (res.statusCode == 401) {
        await TokenStorage.clearTokens();
        throw SessionExpiredException();
      }
    }
    return res;
  }

  // Health check
  static Future<Map<String, dynamic>> health() async {
    final res = await _safeHttp(_httpClient.get(Uri.parse("$apiBase/health/")));
    return await _handleResponse(res);
  }

  // Authentication endpoints
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/login/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username, "password": password}),
    ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> registerCustomer({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
    required String district,
    required String city,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{
      "username": username,
      "email": email,
      "phone": phone,
      "password": password,
      "password_confirm": passwordConfirm,
      "district": district.trim(),
      "city": city.trim(),
    };
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      body["referral_code"] = referralCode.trim();
    }
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/register/customer/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> sendRegistrationOtp({
    required String role,
    required Map<String, dynamic> body,
  }) async {
    final payload = <String, dynamic>{...body, 'role': role};
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/register/send-otp/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> registerProvider({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
    required String profession,
    required String district,
    required String city,
    String? idDocumentType,
    String? idDocumentPath,
    String? certificationFilePath,
    String? idDocumentNumber,
    String? certificateNumber,
    String? additionalDocumentPath,

    /// Each: { "category_id": int, "title": "..." } — creates seva_service rows at price 0.
    List<Map<String, dynamic>>? servicesOffered,
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse("$apiBase/auth/register/provider/"),
    );
    req.fields['username'] = username;
    req.fields['email'] = email;
    req.fields['phone'] = phone;
    req.fields['password'] = password;
    req.fields['password_confirm'] = passwordConfirm;
    req.fields['profession'] = profession;
    req.fields['district'] = district.trim();
    req.fields['city'] = city.trim();
    if (idDocumentType != null && idDocumentType.trim().isNotEmpty) {
      req.fields['id_document_type'] = idDocumentType.trim();
    }
    if (idDocumentNumber != null && idDocumentNumber.trim().isNotEmpty) {
      req.fields['id_document_number'] = idDocumentNumber.trim();
    }
    if (certificateNumber != null && certificateNumber.trim().isNotEmpty) {
      req.fields['certificate_number'] = certificateNumber.trim();
    }
    if (servicesOffered != null && servicesOffered.isNotEmpty) {
      req.fields['services_offered'] = jsonEncode(servicesOffered);
    }
    if (idDocumentPath != null && idDocumentPath.trim().isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath(
          'id_document_file', idDocumentPath.trim()));
    }
    if (certificationFilePath != null &&
        certificationFilePath.trim().isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath(
          'certification_file', certificationFilePath.trim()));
    }
    if (additionalDocumentPath != null &&
        additionalDocumentPath.trim().isNotEmpty) {
      req.files.add(await http.MultipartFile.fromPath(
          'additional_document_file', additionalDocumentPath.trim()));
    }
    final res = await _sendMultipartRequest(req);
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> verifyRegistrationOtp({
    required String email,
    required String role,
    required String code,
  }) async {
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/register/verify-otp/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': email.trim(),
        'role': role.trim().toLowerCase(),
        'code': code.trim(),
      }),
    ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> resendRegistrationOtp({
    required String email,
    required String role,
  }) async {
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/register/resend-otp/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': email.trim(),
        'role': role.trim().toLowerCase(),
      }),
    ));
    return await _handleResponse(res);
  }

  /// Social login: provider is 'google', token is id_token from Google Sign-In.
  /// Returns same shape as login: { user, tokens }.
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
  }) async {
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/social-login/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"provider": provider, "token": token}),
    ));
    return await _handleResponse(res);
  }

  /// Forgot password: sends OTP using a username or email identifier.
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String contactValue,
    required bool isEmail,
  }) async {
    final body = <String, dynamic>{
      'contact_value': contactValue.trim(),
      'is_email': isEmail,
    };
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/forgot-password/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    ));
    return await _handleResponse(res);
  }

  /// Verify reset code; returns { reset_token }.
  static Future<Map<String, dynamic>> verifyResetCode({
    required String contactValue,
    required bool isEmail,
    required String code,
  }) async {
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/verify-reset-code/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "contact_value": contactValue,
        "is_email": isEmail,
        "code": code,
      }),
    ));
    return await _handleResponse(res);
  }

  /// Set new password after verification. Requires reset_token from verifyResetCode.
  static Future<Map<String, dynamic>> setNewPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/set-new-password/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "reset_token": resetToken,
        "new_password": newPassword,
      }),
    ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _authenticated((token) => http.post(
          Uri.parse("$apiBase/auth/change-password/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "current_password": currentPassword,
            "new_password": newPassword,
          }),
        ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> deleteAccount({
    String? password,
  }) async {
    final res = await _authenticated((token) => http.post(
          Uri.parse("$apiBase/auth/delete-account/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            if (password != null && password.isNotEmpty) 'password': password,
          }),
        ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> refreshToken({
    required String refresh,
  }) async {
    final res = await _safeHttp(_httpClient.post(
      Uri.parse("$apiBase/auth/token/refresh/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refresh}),
    ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> me() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/auth/me/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res);
  }

  // Dashboard endpoints
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/dashboard/stats/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getUserProfile() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/profile/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> updates) async {
    final token = await TokenStorage.getAccessToken();
    final res = await http.patch(
      Uri.parse("$apiBase/profile/update/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(updates),
    );
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getCurrentCustomerProfile() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/customer-profile/me/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateCurrentCustomerProfile(
      Map<String, dynamic> updates) async {
    final token = await TokenStorage.getAccessToken();
    final res = await http.patch(
      Uri.parse("$apiBase/customer-profile/me/update/"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(updates),
    );
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> uploadCustomerProfileImage(
      String filePath) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('SESSION_EXPIRED');
    }
    final baseName = filePath.split(RegExp(r'[/\\]')).last;
    final raw = await File(filePath).readAsBytes();
    final prepared = compressImageBytesToJpegUnderLimit(
      raw,
      fileName: baseName,
    );
    final uri = Uri.parse("$apiBase/customer-profile/me/upload-image/");
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        prepared.bytes,
        filename: prepared.fileName,
        contentType: _mediaTypeForImageFileName(prepared.fileName),
      ),
    );
    final res = await _sendMultipartRequest(request);
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getProviderCustomerProfileForBooking(
      String bookingId) async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/customer-profile/provider/bookings/$bookingId/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Upload profile photo; returns full profile map (includes [profile_image_url]).
  static Future<Map<String, dynamic>> uploadProfileImage(
      String filePath) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('SESSION_EXPIRED');
    }
    final baseName = filePath.split(RegExp(r'[/\\]')).last;
    final raw = await File(filePath).readAsBytes();
    final prepared = compressImageBytesToJpegUnderLimit(
      raw,
      fileName: baseName,
    );
    final uri = Uri.parse("$apiBase/profile/upload-image/");
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        prepared.bytes,
        filename: prepared.fileName,
        contentType: _mediaTypeForImageFileName(prepared.fileName),
      ),
    );
    final res = await _sendMultipartRequest(request);
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Fetch categories from backend (seva_servicecategory) so app matches DB.
  static Future<List<dynamic>> getCategories() async {
    const cacheKey = 'categories';
    return _cachedListRequest(
      key: cacheKey,
      loader: () async {
        final res = await _safeHttp(
          http.get(
            Uri.parse("$apiBase/categories/"),
            headers: {"Content-Type": "application/json"},
          ),
        );
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
  }

  /// Fetch providers from backend (seva_auth_user where role=prov) for registration dropdown.
  static Future<List<dynamic>> getProviders() async {
    const cacheKey = 'providers';
    return _cachedListRequest(
      key: cacheKey,
      loader: () async {
        final res = await _safeHttp(
          http.get(
            Uri.parse("$apiBase/providers/"),
            headers: {"Content-Type": "application/json"},
          ),
        );
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
  }

  /// Fetch a single provider profile with live database fields and services.
  static Future<Map<String, dynamic>> getProviderProfile(int providerId) async {
    final res = await http.get(
      Uri.parse("$apiBase/providers/$providerId/"),
      headers: {"Content-Type": "application/json"},
    );
    final data = await _handleResponse(res);
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    return {};
  }

  /// Optional [district] / [city] filter by provider's saved location (registration).
  static Future<List<dynamic>> getServices({
    String? district,
    String? city,
  }) async {
    final params = <String, String>{};
    final d = district?.trim();
    final c = city?.trim();
    if (d != null && d.isNotEmpty) params['district'] = d;
    if (c != null && c.isNotEmpty) params['city'] = c;
    final cacheKey = 'services::${d ?? ''}::${c ?? ''}';
    return _cachedListRequest(
      key: cacheKey,
      loader: () async {
        final uri = Uri.parse("$apiBase/services/").replace(
          queryParameters: params.isEmpty ? null : params,
        );
        final res = await _safeHttp(
          _httpClient.get(
            uri,
            headers: {"Content-Type": "application/json"},
          ),
        );
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
  }

  /// Distinct districts from registered providers (for home filter).
  static Future<List<String>> getLocationDistricts() async {
    const cacheKey = 'location_districts';
    final list = await _cachedListRequest(
      key: cacheKey,
      loader: () async {
        final res = await _safeHttp(
          http.get(
            Uri.parse("$apiBase/locations/districts/"),
            headers: {"Content-Type": "application/json"},
          ),
        );
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
    return list.map((e) => e.toString()).toList();
  }

  /// Cities for providers; pass [district] to narrow list.
  static Future<List<String>> getLocationCities({String? district}) async {
    final districtKey = district?.trim() ?? '';
    final cacheKey = 'location_cities::$districtKey';
    final list = await _cachedListRequest(
      key: cacheKey,
      loader: () async {
        final uri = Uri.parse("$apiBase/locations/cities/").replace(
          queryParameters: (district != null && district.trim().isNotEmpty)
              ? {'district': district.trim()}
              : null,
        );
        final res = await _safeHttp(
          http.get(
            uri,
            headers: {"Content-Type": "application/json"},
          ),
        );
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
    return list.map((e) => e.toString()).toList();
  }

  /// Fetch services for a specific provider (e.g. current provider's services).
  static Future<List<dynamic>> getServicesForProvider(int providerId) async {
    final uri = Uri.parse("$apiBase/services/")
        .replace(queryParameters: {"provider": providerId.toString()});
    final res =
        await http.get(uri, headers: {"Content-Type": "application/json"});
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Fetch services by category so user can choose a provider (e.g. Transportation subcategories).
  /// [forSignup] true = return all sub-services for dropdown (no provider filter); false = only rows where provider profession matches.
  static Future<List<dynamic>> getServicesByCategory(dynamic categoryId,
      {bool forSignup = false}) async {
    final params = <String, String>{"category": categoryId.toString()};
    if (forSignup) params['for_signup'] = '1';
    final uri =
        Uri.parse("$apiBase/services/").replace(queryParameters: params);
    final res =
        await http.get(uri, headers: {"Content-Type": "application/json"});
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  static Future<List<dynamic>> getUserBookings(
      {bool forceRefresh = false}) async {
    final token = await TokenStorage.getAccessToken();
    final cacheKey = _bookingsCacheKey(token);

    if (forceRefresh) {
      _listCache.remove(cacheKey);
      _inflightListRequests.remove(cacheKey);
    }

    return _cachedListRequest(
      key: cacheKey,
      ttl: const Duration(seconds: 30),
      loader: () async {
        final res = await _authenticated((token) => http.get(
              Uri.parse("$apiBase/bookings/"),
              headers: {"Authorization": "Bearer $token"},
            ));
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
  }

  /// Fetch a single booking by id (for notification deep link). User must be customer or provider of that booking.
  static Future<Map<String, dynamic>> getBookingById(String bookingId) async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/bookings/$bookingId/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createBooking({
    required int serviceId,
    required String bookingDate,
    required String bookingTime,
    String? notes,
    required double totalAmount,
    String? address,
    double? latitude,
    double? longitude,
    String? requestImageUrl,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final body = <String, dynamic>{
      "service": serviceId,
      "booking_date": bookingDate,
      "booking_time": bookingTime,
      "notes": notes ?? "",
      "total_amount": totalAmount.toStringAsFixed(2),
    };
    if (requestImageUrl != null && requestImageUrl.isNotEmpty) {
      body["request_image_url"] = requestImageUrl;
    }
    if (address != null && address.isNotEmpty) body["address"] = address;
    if (latitude != null) body["latitude"] = _roundCoord(latitude);
    if (longitude != null) body["longitude"] = _roundCoord(longitude);
    final res = await _httpClient.post(
      Uri.parse("$apiBase/bookings/create/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );
    return await _handleResponse(res);
  }

  /// Ask admins to add a new service category (not a booking).
  /// Supports both [requestedServiceName] and legacy [serviceTitle] callers.
  static Future<Map<String, dynamic>> submitServiceCategoryRequest({
    String? requestedServiceName,
    String? serviceTitle,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
  }) async {
    final name = (requestedServiceName ?? serviceTitle ?? '').trim();
    if (name.isEmpty) {
      throw Exception('Service name is required');
    }
    final token = await TokenStorage.getAccessToken();
    final body = <String, dynamic>{
      'requested_service_name': name,
    };
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    if (address != null && address.trim().isNotEmpty) {
      body['address'] = address.trim();
    }
    if (latitude != null) body['latitude'] = _roundCoord(latitude);
    if (longitude != null) body['longitude'] = _roundCoord(longitude);
    if (imageUrls != null && imageUrls.isNotEmpty) {
      body['image_urls'] = imageUrls;
    }
    final res = await http.post(
      Uri.parse("$apiBase/service-category-requests/create/"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Upload a reference image before [createBooking]; returns signed URL for [request_image_url].
  static Future<String> uploadBookingRequestImage(String filePath) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('SESSION_EXPIRED');
    }
    final baseName = filePath.split(RegExp(r'[/\\]')).last;
    final raw = await File(filePath).readAsBytes();
    final prepared = compressImageBytesToJpegUnderLimit(
      raw,
      fileName: baseName,
    );
    final uri = Uri.parse("$apiBase/bookings/upload-request-image/");
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        prepared.bytes,
        filename: prepared.fileName,
        contentType: _mediaTypeForImageFileName(prepared.fileName),
      ),
    );
    final res = await _sendMultipartRequest(request);
    final data = await _handleResponse(res) as Map<String, dynamic>;
    final url = data['request_image_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No image URL returned');
    }
    return url;
  }

  /// Google Places autocomplete (backend proxy). Returns map with 'predictions' list and optional 'error' string.
  static Future<Map<String, dynamic>> getPlacesAutocompleteWithError(
      String input) async {
    if (input.trim().length < 2) {
      return {'predictions': <Map<String, dynamic>>[]};
    }
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/places/autocomplete/")
              .replace(queryParameters: {"input": input.trim()}),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res) as Map<String, dynamic>?;
    final list = data?["predictions"] as List<dynamic>?;
    final predictions = list != null
        ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    return {
      'predictions': predictions,
      if (data?['error'] != null) 'error': data!['error'] as String,
      if (data?['hint'] != null) 'hint': data!['hint'] as String,
    };
  }

  /// Google Places autocomplete (backend proxy). Returns list of {place_id, description}.
  static Future<List<Map<String, dynamic>>> getPlacesAutocomplete(
      String input) async {
    final result = await getPlacesAutocompleteWithError(input);
    return List<Map<String, dynamic>>.from(
        result['predictions'] as List? ?? []);
  }

  /// Place details by place_id. Returns {formatted_address, latitude, longitude}.
  static Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/places/details/")
              .replace(queryParameters: {"place_id": placeId}),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res) as Map<String, dynamic>?;
    return data;
  }

  /// Reverse geocode lat/lng to address (backend proxy).
  static Future<String> reverseGeocode(double lat, double lng) async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/places/reverse-geocode/")
              .replace(queryParameters: {"lat": "$lat", "lng": "$lng"}),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res) as Map<String, dynamic>?;
    return (data?["formatted_address"] as String?) ?? "";
  }

  static Future<List<dynamic>> getProviderNotifications() async {
    const cacheKey = 'auth_provider_notifications';
    return _cachedListRequest(
      key: cacheKey,
      ttl: const Duration(seconds: 8),
      loader: () async {
        final res = await _authenticated((token) => http.get(
              Uri.parse("$apiBase/notifications/"),
              headers: {"Authorization": "Bearer $token"},
            ));
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
  }

  static Future<List<dynamic>> getMyReviews() async {
    const cacheKey = 'auth_my_reviews';
    return _cachedListRequest(
      key: cacheKey,
      ttl: const Duration(seconds: 12),
      loader: () async {
        final res = await _authenticated((token) => http.get(
              Uri.parse("$apiBase/reviews/"),
              headers: {"Authorization": "Bearer $token"},
            ));
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
  }

  /// Fetch current customer's review for a specific booking.
  static Future<Map<String, dynamic>> getReviewForBooking(int bookingId) async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/reviews/booking/$bookingId/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res);
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    return {'exists': false, 'booking_id': bookingId};
  }

  /// Create a review for a completed booking (customer only). Rating 1–5, comment optional.
  static Future<Map<String, dynamic>> createReview({
    required int bookingId,
    required int rating,
    String comment = '',
  }) async {
    final res = await _authenticated((token) => http.post(
          Uri.parse("$apiBase/reviews/create/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "booking_id": bookingId,
            "rating": rating,
            "comment": comment,
          }),
        ));
    return await _handleResponse(res);
  }

  /// Reviews received by the current provider.
  static Future<Map<String, dynamic>> getProviderReviews() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/reviews/received/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res);
    if (data is Map<String, dynamic>) {
      final mapped = Map<String, dynamic>.from(data);
      final reviews = mapped['reviews'];
      if (reviews is List) {
        mapped['reviews'] = List<dynamic>.from(reviews);
      } else {
        mapped['reviews'] = <dynamic>[];
      }
      mapped['summary'] = mapped['summary'] is Map
          ? Map<String, dynamic>.from(mapped['summary'] as Map)
          : <String, dynamic>{
              'total_reviews': 0,
              'average_rating': 0.0,
              'distribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
            };
      return mapped;
    }
    if (data is List) {
      return {
        'summary': {
          'total_reviews': data.length,
          'average_rating': 0.0,
          'distribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
        },
        'reviews': List<dynamic>.from(data),
      };
    }
    return {
      'summary': {
        'total_reviews': 0,
        'average_rating': 0.0,
        'distribution': {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
      },
      'reviews': <dynamic>[],
    };
  }

  static Future<List<dynamic>> getCustomerNotifications() async {
    const cacheKey = 'auth_customer_notifications';
    return _cachedListRequest(
      key: cacheKey,
      ttl: const Duration(seconds: 8),
      loader: () async {
        final res = await _authenticated((token) => http.get(
              Uri.parse("$apiBase/customer-notifications/"),
              headers: {"Authorization": "Bearer $token"},
            ));
        final data = await _handleResponse(res);
        if (data is List) return List<dynamic>.from(data);
        return <dynamic>[];
      },
    );
  }

  /// Promotional banners (public).
  static Future<List<dynamic>> getPromotionalBanners() async {
    final res = await http.get(
      Uri.parse("$apiBase/promotional-banners/"),
      headers: {"Content-Type": "application/json"},
    );
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Blog posts (public).
  static Future<List<dynamic>> getBlogs() async {
    final res = await http.get(
      Uri.parse("$apiBase/blogs/"),
      headers: {"Content-Type": "application/json"},
    );
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Referral & Loyalty: get current user's referral code, points, and history.
  static Future<Map<String, dynamic>> getReferralProfile() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/referral-profile/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Favorites summary for card heart states.
  static Future<Map<String, dynamic>> getFavoritesSummary() async {
    try {
      final res = await _authenticated((token) => http.get(
            Uri.parse("$apiBase/favorites/summary/"),
            headers: {"Authorization": "Bearer $token"},
          ));
      return await _handleResponse(res) as Map<String, dynamic>;
    } catch (e) {
      if (_isFavoriteTableMissingError(e)) {
        throw _friendlyFavoriteSetupException();
      }
      rethrow;
    }
  }

  /// Favorite providers list (separate from favorite services).
  static Future<List<dynamic>> getFavoriteProviders() async {
    try {
      final res = await _authenticated((token) => http.get(
            Uri.parse("$apiBase/favorites/providers/"),
            headers: {"Authorization": "Bearer $token"},
          ));
      final data = await _handleResponse(res);
      if (data is List) return List<dynamic>.from(data);
      return [];
    } catch (e) {
      if (_isFavoriteTableMissingError(e)) {
        throw _friendlyFavoriteSetupException();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addFavoriteProvider(
      int providerId) async {
    try {
      final res = await _authenticated((token) => http.post(
            Uri.parse("$apiBase/favorites/providers/add/"),
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"provider_id": providerId}),
          ));
      return await _handleResponse(res) as Map<String, dynamic>;
    } catch (e) {
      if (_isFavoriteTableMissingError(e)) {
        throw _friendlyFavoriteSetupException();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> removeFavoriteProvider(
      int providerId) async {
    try {
      final res = await _authenticated((token) => http.delete(
            Uri.parse("$apiBase/favorites/providers/$providerId/"),
            headers: {"Authorization": "Bearer $token"},
          ));
      return await _handleResponse(res) as Map<String, dynamic>;
    } catch (e) {
      if (_isFavoriteTableMissingError(e)) {
        throw _friendlyFavoriteSetupException();
      }
      rethrow;
    }
  }

  /// Favorite services list (separate from favorite providers).
  static Future<List<dynamic>> getFavoriteServices() async {
    try {
      final res = await _authenticated((token) => http.get(
            Uri.parse("$apiBase/favorites/services/"),
            headers: {"Authorization": "Bearer $token"},
          ));
      final data = await _handleResponse(res);
      if (data is List) return List<dynamic>.from(data);
      return [];
    } catch (e) {
      if (_isFavoriteTableMissingError(e)) {
        throw _friendlyFavoriteSetupException();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addFavoriteService(int serviceId) async {
    try {
      final res = await _authenticated((token) => http.post(
            Uri.parse("$apiBase/favorites/services/add/"),
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"service_id": serviceId}),
          ));
      return await _handleResponse(res) as Map<String, dynamic>;
    } catch (e) {
      if (_isFavoriteTableMissingError(e)) {
        throw _friendlyFavoriteSetupException();
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> removeFavoriteService(
      int serviceId) async {
    try {
      final res = await _authenticated((token) => http.delete(
            Uri.parse("$apiBase/favorites/services/$serviceId/"),
            headers: {"Authorization": "Bearer $token"},
          ));
      return await _handleResponse(res) as Map<String, dynamic>;
    } catch (e) {
      if (_isFavoriteTableMissingError(e)) {
        throw _friendlyFavoriteSetupException();
      }
      rethrow;
    }
  }

  /// Wallet: get balance and transaction history for current user.
  static Future<Map<String, dynamic>> getWallet(
      {bool forceRefresh = false}) async {
    if (forceRefresh) {
      _walletCache = null;
      _inflightWalletRequest = null;
    }

    final cached = _getCachedWallet();
    if (cached != null) return cached;

    final inFlight = _inflightWalletRequest;
    if (inFlight != null) {
      final shared = await inFlight;
      return Map<String, dynamic>.from(shared);
    }

    final future = () async {
      final res = await _authenticated((token) => http.get(
            Uri.parse("$apiBase/wallet/"),
            headers: {"Authorization": "Bearer $token"},
          ));
      final data = await _handleResponse(res);
      if (data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data);
      }
      if (data is Map) {
        return Map<String, dynamic>.fromEntries(
          data.entries.map(
            (entry) => MapEntry(entry.key.toString(), entry.value),
          ),
        );
      }
      return <String, dynamic>{};
    }();

    _inflightWalletRequest = future;
    try {
      final loaded = await future;
      _setCachedWallet(loaded);
      return Map<String, dynamic>.from(loaded);
    } finally {
      _inflightWalletRequest = null;
    }
  }

  /// Chat: list conversation threads (bookings) for current user.
  static Future<List<dynamic>> getChatThreads() async {
    final res = await _authenticated((token) => _httpClient.get(
          Uri.parse("$apiBase/chat/threads/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Chat: get messages for a booking (thread).
  static Future<List<dynamic>> getChatMessages({
    required int bookingId,
  }) async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/chat/threads/$bookingId/messages/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Chat: send a message for a booking (thread).
  static Future<Map<String, dynamic>> sendChatMessage({
    required int bookingId,
    required String message,
  }) async {
    final res = await _authenticated((token) => _httpClient.post(
          Uri.parse("$apiBase/chat/threads/$bookingId/messages/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"message": message}),
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Chat: send a message with an attachment using multipart upload.
  /// Backend stores the file in Supabase Storage and returns a signed `attachment_url`.
  static Future<Map<String, dynamic>> sendChatAttachment({
    required int bookingId,
    required List<int> fileBytes,
    required String fileName,
    String? mimeType,
    String? message,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('SESSION_EXPIRED');
    }

    final uri = Uri.parse("$apiBase/chat/threads/$bookingId/messages/");
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['message'] = (message ?? '').trim();

    final contentType = (mimeType == null || mimeType.isEmpty)
        ? null
        : MediaType.parse(mimeType);

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: contentType,
      ),
    );

    // Note: We intentionally keep content-type simple here; backend will also
    // infer mime type from filename if needed.

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final res = await http.Response.fromStream(streamed);
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Chat: delete a message. Only the sender can delete their own message.
  static Future<Map<String, dynamic>> deleteChatMessage({
    required int bookingId,
    required int messageId,
  }) async {
    final res = await _authenticated((token) => http.delete(
          Uri.parse(
              "$apiBase/chat/threads/$bookingId/messages/$messageId/delete/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Provider: list verification documents (Verify Your Id).
  static Future<List<dynamic>> getProviderVerifications() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/provider-verifications/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Provider: add a verification document (JSON, no file).
  static Future<Map<String, dynamic>> createProviderVerification({
    required String documentType,
    String? documentNumber,
    String? documentUrl,
  }) async {
    final res = await _authenticated((token) => http.post(
          Uri.parse("$apiBase/provider-verifications/create/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "document_type": documentType,
            if (documentNumber != null && documentNumber.isNotEmpty)
              "document_number": documentNumber,
            if (documentUrl != null && documentUrl.isNotEmpty)
              "document_url": documentUrl,
          }),
        ));
    return await _handleResponse(res);
  }

  /// Provider: add a verification document with file upload (image or PDF). [filePath] for mobile/desktop.
  static Future<Map<String, dynamic>> createProviderVerificationWithFile({
    required String documentType,
    required String filePath,
    String? documentNumber,
    String? fileName,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse("$apiBase/provider-verifications/create/");
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['document_type'] = documentType;
    if (documentNumber != null && documentNumber.isNotEmpty) {
      request.fields['document_number'] = documentNumber;
    }
    final file = await http.MultipartFile.fromPath(
      'file',
      filePath,
      filename: fileName ?? filePath.split(RegExp(r'[/\\]')).last,
    );
    request.files.add(file);
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    return await _handleResponse(res);
  }

  /// Provider: add a verification document with file bytes (e.g. from web file picker).
  static Future<Map<String, dynamic>> createProviderVerificationWithFileBytes({
    required String documentType,
    required List<int> bytes,
    required String fileName,
    String? documentNumber,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse("$apiBase/provider-verifications/create/");
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['document_type'] = documentType;
    if (documentNumber != null && documentNumber.isNotEmpty) {
      request.fields['document_number'] = documentNumber;
    }
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    return await _handleResponse(res);
  }

  /// Provider: delete a verification document.
  static Future<void> deleteProviderVerification(int verificationId) async {
    final res = await _authenticated((token) => http.delete(
          Uri.parse("$apiBase/provider-verifications/$verificationId/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    final body = res.body;
    try {
      final j = jsonDecode(body) as Map<String, dynamic>?;
      final msg = j?['error'] ?? j?['message'] ?? body;
      throw Exception(msg);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(body);
    }
  }

  /// Update provider verification document (document_number or file).
  static Future<Map<String, dynamic>> updateProviderVerification({
    required int verificationId,
    String? documentNumber,
    String? filePath,
  }) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('SESSION_EXPIRED');
    }

    if (filePath != null && filePath.isNotEmpty) {
      // Update with file upload
      final baseName = filePath.split(RegExp(r'[/\\]')).last;
      final raw = await File(filePath).readAsBytes();
      final prepared = compressImageBytesToJpegUnderLimit(
        raw,
        fileName: baseName,
      );
      final uri = Uri.parse("$apiBase/provider-verifications/$verificationId/");
      final request = http.MultipartRequest('PATCH', uri);
      request.headers['Authorization'] = 'Bearer $token';
      if (documentNumber != null && documentNumber.isNotEmpty) {
        request.fields['document_number'] = documentNumber;
      }
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          prepared.bytes,
          filename: prepared.fileName,
          contentType: _mediaTypeForImageFileName(prepared.fileName),
        ),
      );
      final res = await _sendMultipartRequest(request);
      return await _handleResponse(res) as Map<String, dynamic>;
    } else {
      // Update without file (just document number)
      final res = await _authenticated((token) => http.patch(
            Uri.parse("$apiBase/provider-verifications/$verificationId/"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $token",
            },
            body: jsonEncode({
              if (documentNumber != null) 'document_number': documentNumber,
            }),
          ));
      return await _handleResponse(res) as Map<String, dynamic>;
    }
  }

  /// Initiate eSewa payment; returns { payment_url, transaction_id, amount }.
  static Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    required double amount,
  }) async {
    final res = await _authenticated((token) => _httpClient
        .post(
          Uri.parse("$apiBase/payments/initiate/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "booking_id": int.tryParse(bookingId) ?? bookingId,
            "amount": amount,
          }),
        )
        .timeout(const Duration(seconds: 15)));
    return await _handleResponse(res);
  }

  /// Verify eSewa SDK payment via backend (refId) and mark complete.
  /// Called after EsewaFlutterSdk.initPayment onPaymentSuccess.
  static Future<Map<String, dynamic>> verifyAndCompletePayment({
    required String refId,
    required String productId,
    required String bookingId,
    required String totalAmount,
  }) async {
    final res = await _authenticated((token) => http.post(
          Uri.parse("$apiBase/payments/verify-complete/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "ref_id": refId,
            "product_id": productId,
            "booking_id": int.tryParse(bookingId) ?? bookingId,
            "total_amount": totalAmount,
          }),
        ));
    return await _handleResponse(res);
  }

  /// Mark payment as completed without eSewa (for testing when gateway is unreachable).
  static Future<Map<String, dynamic>> completeDemoPayment({
    required String bookingId,
    String? transactionId,
  }) async {
    final res = await _authenticated((token) => http.post(
          Uri.parse("$apiBase/payments/demo-complete/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "booking_id": int.tryParse(bookingId) ?? bookingId,
            if (transactionId != null && transactionId.isNotEmpty)
              "transaction_id": transactionId,
          }),
        ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getReceiptByBooking(
      String bookingId) async {
    final id = int.tryParse(bookingId) ?? bookingId;
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/receipts/booking/$id/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> getReceiptDetail(int receiptId) async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/receipts/$receiptId/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> getMyReceipts() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/receipts/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    final body = await _handleResponse(res);
    if (body is List) return body;
    return [];
  }

  static Future<List<dynamic>> getProviderTimeSlots({
    int? providerId,
    String? slotDate,
    bool activeOnly = true,
  }) async {
    final params = <String, String>{};
    if (providerId != null) {
      params['provider_id'] = providerId.toString();
    }
    if (slotDate != null && slotDate.trim().isNotEmpty) {
      params['slot_date'] = slotDate.trim();
    }
    if (!activeOnly) {
      params['active_only'] = '0';
    }
    final uri = Uri.parse("$apiBase/provider-time-slots/")
        .replace(queryParameters: params.isEmpty ? null : params);
    final res = await _authenticated((token) => http.get(
          uri,
          headers: {"Authorization": "Bearer $token"},
        ));
    final body = await _handleResponse(res);
    if (body is List) return body;
    return [];
  }

  static Future<Map<String, dynamic>> createProviderTimeSlot({
    required String slotDate,
    required String startTime,
    required String endTime,
    String? note,
    bool isActive = true,
  }) async {
    final res = await _authenticated((token) => http.post(
          Uri.parse("$apiBase/provider-time-slots/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            'slot_date': slotDate,
            'start_time': startTime,
            'end_time': endTime,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            'is_active': isActive,
          }),
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProviderTimeSlot({
    required int slotId,
    String? slotDate,
    String? startTime,
    String? endTime,
    String? note,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (slotDate != null) body['slot_date'] = slotDate;
    if (startTime != null) body['start_time'] = startTime;
    if (endTime != null) body['end_time'] = endTime;
    if (note != null) body['note'] = note;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _authenticated((token) => http.patch(
          Uri.parse("$apiBase/provider-time-slots/$slotId/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode(body),
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<void> deleteProviderTimeSlot(int slotId) async {
    final res = await _authenticated((token) => http.delete(
          Uri.parse("$apiBase/provider-time-slots/$slotId/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateBookingStatus(
    String bookingId,
    String status, {
    Object? quotedPrice,
    String? cancelReason,
  }) async {
    final uri = Uri.parse("$apiBase/bookings/$bookingId/update/");
    const timeout = Duration(seconds: 20);
    final payload = <String, dynamic>{"status": status};
    if (quotedPrice != null) payload["quoted_price"] = quotedPrice;
    if (cancelReason != null && cancelReason.trim().isNotEmpty) {
      payload["cancel_reason"] = cancelReason.trim();
    }
    try {
      final res = await _authenticated((token) => http
          .patch(
            uri,
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout));
      return await _handleResponse(res);
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      final msg = e.toString();
      if (msg.contains('10035') ||
          msg.contains('timed out') ||
          msg.contains('SocketException')) {
        try {
          final res = await _authenticated((token) => http
              .patch(uri,
                  headers: {
                    "Authorization": "Bearer $token",
                    "Content-Type": "application/json",
                  },
                  body: jsonEncode(payload))
              .timeout(timeout));
          return await _handleResponse(res);
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> providerReviewRefund({
    required int refundId,
    required String action, // approve | reject
    String? note,
  }) async {
    final res = await _authenticated((token) => _httpClient.post(
          Uri.parse("$apiBase/refunds/$refundId/provider-review/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "action": action,
            if (note != null && note.trim().isNotEmpty) "note": note.trim(),
          }),
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Get list of refunds for current user (filtered by role)
  static Future<List<dynamic>> getRefunds() async {
    final res = await _authenticated((token) => _httpClient.get(
          Uri.parse("$apiBase/refunds/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  static Future<Map<String, dynamic>> getProviderVerificationStatus() async {
    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/provider-verifications/status/"),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Hamro Sewa AI (RAG): natural language question; backend retrieves real providers then calls OpenRouter.
  static Future<Map<String, dynamic>> aiQuery(String query) async {
    final res = await _authenticated((token) => http
        .post(
          Uri.parse("$apiBase/ai/query/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"query": query.trim()}),
        )
        .timeout(const Duration(seconds: 90)));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Hamro Sewa AI: fetch current user's query/answer history, with optional date range and text search.
  static Future<Map<String, dynamic>> aiHistory({
    String? startDate, // YYYY-MM-DD
    String? endDate, // YYYY-MM-DD
    String? search,
    int limit = 200,
  }) async {
    final params = <String, String>{};
    if (startDate != null && startDate.trim().isNotEmpty) {
      params['start_date'] = startDate.trim();
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      params['end_date'] = endDate.trim();
    }
    if (search != null && search.trim().isNotEmpty) {
      params['q'] = search.trim();
    }
    params['limit'] = limit.toString();

    final res = await _authenticated((token) => http.get(
          Uri.parse("$apiBase/ai/history/").replace(queryParameters: params),
          headers: {"Authorization": "Bearer $token"},
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }

  /// Admin approves or rejects a refund
  /// [action]: 'approve' or 'reject'
  /// [refundId]: ID of the refund to review
  /// [refundReference]: Required for approval (e.g., eSewa reference)
  /// [adminNote]: Required for rejection (reason for rejection)
  static Future<Map<String, dynamic>> reviewRefund({
    required int refundId,
    required String action,
    String? refundReference,
    String? adminNote,
  }) async {
    final body = {
      'action': action,
      if (refundReference != null) 'refund_reference': refundReference,
      if (adminNote != null) 'admin_note': adminNote,
    };

    final res = await _authenticated((token) => _httpClient.post(
          Uri.parse("$apiBase/refunds/$refundId/review/"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json",
          },
          body: jsonEncode(body),
        ));
    return await _handleResponse(res) as Map<String, dynamic>;
  }
}
