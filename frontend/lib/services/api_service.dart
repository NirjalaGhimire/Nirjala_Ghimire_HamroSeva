import 'dart:convert';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

/// Thrown when the access token is invalid and refresh failed or was not possible.
/// App should clear tokens and redirect to login when this is caught.
class SessionExpiredException implements Exception {
  @override
  String toString() => 'SESSION_EXPIRED';
}

class ApiService {
  // On Android emulator use 10.0.2.2 to reach host. On real device use 127.0.0.1 (with adb reverse tcp:8000 tcp:8000).
  static String? _apiBase;
  static String get apiBase => _apiBase ?? _defaultApiBase;
  static String get _defaultApiBase => Platform.isAndroid
      ? "http://10.0.2.2:8000/api"
      : "http://127.0.0.1:8000/api";

  /// Call once before runApp (e.g. from main()) so real device uses 127.0.0.1 when connected via adb reverse.
  static Future<void> init() async {
    if (!Platform.isAndroid) {
      _apiBase = "http://127.0.0.1:8000/api";
      return;
    }
    try {
      final deviceInfo = DeviceInfoPlugin();
      final android = await deviceInfo.androidInfo;
      if (android.isPhysicalDevice) {
        _apiBase = "http://127.0.0.1:8000/api";
      } else {
        _apiBase = "http://10.0.2.2:8000/api";
      }
    } catch (_) {
      _apiBase = _defaultApiBase;
    }
  }

  /// Timeout so login/register don't spin forever if the server is unreachable.
  static const Duration _timeout = Duration(seconds: 15);

  static Future<dynamic> _handleResponse(http.Response res) async {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body);
      } catch (e) {
        return {"message": "Success", "data": res.body};
      }
    } else {
      try {
        final error = jsonDecode(res.body) as Map<String, dynamic>?;
        if (error != null) {
          final msg = error["message"] as String?;
          if (msg != null && msg.isNotEmpty) {
            throw Exception(msg);
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

  /// Runs an authenticated request. On 401, tries refresh once and retries; if still 401, clears tokens and throws [SessionExpiredException].
  static Future<http.Response> _authenticated(Future<http.Response> Function(String? token) run) async {
    String? token = await TokenStorage.getAccessToken();
    http.Response res = await run(token);
    if (res.statusCode == 401) {
      String? refresh = await TokenStorage.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        try {
          final data = await refreshToken(refresh: refresh);
          final newAccess = data['access'] as String?;
          if (newAccess != null) {
            await TokenStorage.saveTokens(accessToken: newAccess, refreshToken: refresh);
            res = await run(newAccess);
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
    final res = await http.get(Uri.parse("$apiBase/health/"));
    return await _handleResponse(res);
  }

  // Authentication endpoints
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final res = await http
        .post(
          Uri.parse("$apiBase/auth/login/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"username": username, "password": password}),
        )
        .timeout(_timeout);
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> registerCustomer({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
    String? referralCode,
  }) async {
    final body = <String, dynamic>{
      "username": username,
      "email": email,
      "phone": phone,
      "password": password,
      "password_confirm": passwordConfirm,
    };
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      body["referral_code"] = referralCode.trim();
    }
    final res = await http
        .post(
          Uri.parse("$apiBase/auth/register/customer/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> registerProvider({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
    required String profession,
  }) async {
    final res = await http
        .post(
          Uri.parse("$apiBase/auth/register/provider/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "username": username,
            "email": email,
            "phone": phone,
            "password": password,
            "password_confirm": passwordConfirm,
            "profession": profession,
          }),
        )
        .timeout(_timeout);
    return await _handleResponse(res);
  }

  /// Social login: provider is 'facebook' or 'google', token is access_token (FB) or id_token (Google).
  /// Returns same shape as login: { user, tokens }.
  static Future<Map<String, dynamic>> socialLogin({
    required String provider,
    required String token,
  }) async {
    final res = await http
        .post(
          Uri.parse("$apiBase/auth/social-login/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"provider": provider, "token": token}),
        )
        .timeout(_timeout);
    return await _handleResponse(res);
  }

  /// Forgot password: send code to email or phone. Body email or phone (one required).
  static Future<Map<String, dynamic>> requestPasswordReset({
    String? email,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (email != null && email.trim().isNotEmpty) body['email'] = email.trim();
    if (phone != null && phone.trim().isNotEmpty) body['phone'] = phone.trim();
    final res = await http
        .post(
          Uri.parse("$apiBase/auth/forgot-password/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return await _handleResponse(res);
  }

  /// Verify reset code; returns { reset_token }.
  static Future<Map<String, dynamic>> verifyResetCode({
    required String contactValue,
    required bool isEmail,
    required String code,
  }) async {
    final res = await http
        .post(
          Uri.parse("$apiBase/auth/verify-reset-code/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contact_value": contactValue,
            "is_email": isEmail,
            "code": code,
          }),
        )
        .timeout(_timeout);
    return await _handleResponse(res);
  }

  /// Set new password after verification. Requires reset_token from verifyResetCode.
  static Future<Map<String, dynamic>> setNewPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    final res = await http
        .post(
          Uri.parse("$apiBase/auth/set-new-password/"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "reset_token": resetToken,
            "new_password": newPassword,
          }),
        )
        .timeout(_timeout);
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> refreshToken({
    required String refresh,
  }) async {
    final res = await http.post(
      Uri.parse("$apiBase/auth/token/refresh/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refresh}),
    );
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

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> updates) async {
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

  /// Fetch categories from backend (seva_servicecategory) so app matches DB.
  static Future<List<dynamic>> getCategories() async {
    final res = await http.get(
      Uri.parse("$apiBase/categories/"),
      headers: {"Content-Type": "application/json"},
    );
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Fetch providers from backend (seva_auth_user where role=prov) for registration dropdown.
  static Future<List<dynamic>> getProviders() async {
    final res = await http.get(
      Uri.parse("$apiBase/providers/"),
      headers: {"Content-Type": "application/json"},
    );
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  static Future<List<dynamic>> getServices() async {
    final res = await http.get(
      Uri.parse("$apiBase/services/"),
      headers: {"Content-Type": "application/json"},
    );
    final data = await _handleResponse(res);
    if (data is List) {
      return List<dynamic>.from(data);
    }
    return [];
  }

  /// Fetch services for a specific provider (e.g. current provider's services).
  static Future<List<dynamic>> getServicesForProvider(int providerId) async {
    final uri = Uri.parse("$apiBase/services/").replace(queryParameters: {"provider": providerId.toString()});
    final res = await http.get(uri, headers: {"Content-Type": "application/json"});
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  /// Fetch services by category so user can choose a provider (e.g. Transportation subcategories).
  /// [forSignup] true = return all sub-services for dropdown (no provider filter); false = only rows where provider profession matches.
  static Future<List<dynamic>> getServicesByCategory(dynamic categoryId, {bool forSignup = false}) async {
    final params = <String, String>{"category": categoryId.toString()};
    if (forSignup) params['for_signup'] = '1';
    final uri = Uri.parse("$apiBase/services/").replace(queryParameters: params);
    final res = await http.get(uri, headers: {"Content-Type": "application/json"});
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  static Future<List<dynamic>> getUserBookings() async {
    final res = await _authenticated((token) => http.get(
      Uri.parse("$apiBase/bookings/"),
      headers: {"Authorization": "Bearer $token"},
    ));
    final data = await _handleResponse(res);
    if (data is List) {
      return List<dynamic>.from(data);
    }
    return [];
  }

  static Future<Map<String, dynamic>> createBooking({
    required int serviceId,
    required String bookingDate,
    required String bookingTime,
    String? notes,
    required double totalAmount,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final res = await http.post(
      Uri.parse("$apiBase/bookings/create/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "service": serviceId,
        "booking_date": bookingDate,
        "booking_time": bookingTime,
        "notes": notes ?? "",
        "total_amount": totalAmount.toStringAsFixed(2),
      }),
    );
    return await _handleResponse(res);
  }

  static Future<List<dynamic>> getProviderNotifications() async {
    final res = await _authenticated((token) => http.get(
      Uri.parse("$apiBase/notifications/"),
      headers: {"Authorization": "Bearer $token"},
    ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  static Future<List<dynamic>> getMyReviews() async {
    final res = await _authenticated((token) => http.get(
      Uri.parse("$apiBase/reviews/"),
      headers: {"Authorization": "Bearer $token"},
    ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
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
  static Future<List<dynamic>> getProviderReviews() async {
    final res = await _authenticated((token) => http.get(
      Uri.parse("$apiBase/reviews/received/"),
      headers: {"Authorization": "Bearer $token"},
    ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  static Future<List<dynamic>> getCustomerNotifications() async {
    final res = await _authenticated((token) => http.get(
      Uri.parse("$apiBase/customer-notifications/"),
      headers: {"Authorization": "Bearer $token"},
    ));
    final data = await _handleResponse(res);
    if (data is List) return List<dynamic>.from(data);
    return [];
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
        if (documentNumber != null && documentNumber.isNotEmpty) "document_number": documentNumber,
        if (documentUrl != null && documentUrl.isNotEmpty) "document_url": documentUrl,
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

  /// Initiate eSewa payment; returns { payment_url, transaction_id, amount }.
  static Future<Map<String, dynamic>> initiatePayment({
    required String bookingId,
    required double amount,
  }) async {
    final res = await _authenticated((token) => http
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
            if (transactionId != null && transactionId.isNotEmpty) "transaction_id": transactionId,
          }),
        ));
    return await _handleResponse(res);
  }

  static Future<Map<String, dynamic>> updateBookingStatus(
    String bookingId,
    String status,
  ) async {
    final uri = Uri.parse("$apiBase/bookings/$bookingId/update/");
    const timeout = Duration(seconds: 20);
    try {
      final res = await _authenticated((token) => http
          .patch(
            uri,
            headers: {
              "Authorization": "Bearer $token",
              "Content-Type": "application/json",
            },
            body: jsonEncode({"status": status}),
          )
          .timeout(timeout));
      return await _handleResponse(res);
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      final msg = e.toString();
      if (msg.contains('10035') || msg.contains('timed out') || msg.contains('SocketException')) {
        try {
          final res = await _authenticated((token) => http
              .patch(uri, headers: {
                "Authorization": "Bearer $token",
                "Content-Type": "application/json",
              }, body: jsonEncode({"status": status}))
              .timeout(timeout));
          return await _handleResponse(res);
        } catch (_) {
          rethrow;
        }
      }
      rethrow;
    }
  }
}
