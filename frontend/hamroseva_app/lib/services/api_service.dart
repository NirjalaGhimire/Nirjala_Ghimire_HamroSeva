import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8000";
  static const String apiBase = "$baseUrl/api";

  // ---------- helpers ----------
  static dynamic _decodeBody(http.Response response) {
    final body = response.body;

    // if backend sends HTML (404/500 page), jsonDecode will fail
    try {
      return jsonDecode(body);
    } catch (_) {
      final preview = body.substring(0, body.length > 250 ? 250 : body.length);
      throw Exception("Non-JSON response (${response.statusCode}): $preview");
    }
  }

  static Map<String, String> _jsonHeaders({String? token}) {
    final h = <String, String>{"Content-Type": "application/json"};
    if (token != null) h["Authorization"] = "Bearer $token";
    return h;
  }

  static Future<http.Response> _getWithAuth(String path) async {
    String? access = await TokenStorage.getAccessToken();
    if (access == null) throw Exception("No access token. Please login.");

    Future<http.Response> call(String token) {
      final url = Uri.parse("$apiBase$path");
      return http.get(url, headers: _jsonHeaders(token: token));
    }

    var response = await call(access);

    if (response.statusCode == 401) {
      access = await refreshAccessToken();
      response = await call(access);
    }

    return response;
  }

  static Future<http.Response> _postWithAuth(String path, {Map<String, dynamic>? body}) async {
    String? access = await TokenStorage.getAccessToken();
    if (access == null) throw Exception("No access token. Please login.");

    Future<http.Response> call(String token) {
      final url = Uri.parse("$apiBase$path");
      return http.post(
        url,
        headers: _jsonHeaders(token: token),
        body: body == null ? null : jsonEncode(body),
      );
    }

    var response = await call(access);

    if (response.statusCode == 401) {
      access = await refreshAccessToken();
      response = await call(access);
    }

    return response;
  }

  // ---------- Health Check ----------
  static Future<Map<String, dynamic>> healthCheck() async {
    final url = Uri.parse("$apiBase/health/");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return _decodeBody(response) as Map<String, dynamic>;
    }
    throw Exception("Failed: ${response.statusCode} ${response.body}");
  }

  // ---------- Register Customer ----------
  static Future<Map<String, dynamic>> registerCustomer({
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse("$apiBase/auth/register/customer/");
    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        "username": username,
        "email": email,
        "phone": phone,
        "password": password,
      }),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 201) {
      final tokens = data["tokens"];
      await TokenStorage.saveTokens(
        access: tokens["access"],
        refresh: tokens["refresh"],
      );
      return data as Map<String, dynamic>;
    }

    throw Exception(data.toString());
  }

  // ---------- Register Provider (WITH profession) ----------
  static Future<Map<String, dynamic>> registerProvider({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String profession,
  }) async {
    final url = Uri.parse("$apiBase/auth/register/provider/");
    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        "username": username,
        "email": email,
        "phone": phone,
        "password": password,
        "profession": profession,
      }),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 201) {
      final tokens = data["tokens"];
      await TokenStorage.saveTokens(
        access: tokens["access"],
        refresh: tokens["refresh"],
      );
      return data as Map<String, dynamic>;
    }

    throw Exception(data.toString());
  }

  // ---------- Login ----------
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse("$apiBase/auth/login/");
    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      final tokens = data["tokens"];
      await TokenStorage.saveTokens(
        access: tokens["access"],
        refresh: tokens["refresh"],
      );
      return data as Map<String, dynamic>;
    }

    throw Exception(data.toString());
  }

  // ---------- Refresh Token ----------
  static Future<String> refreshAccessToken() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null) throw Exception("No refresh token saved");

    final url = Uri.parse("$apiBase/auth/token/refresh/");
    final response = await http.post(
      url,
      headers: _jsonHeaders(),
      body: jsonEncode({"refresh": refresh}),
    );

    final data = _decodeBody(response);

    if (response.statusCode == 200 && data["access"] != null) {
      final newAccess = data["access"] as String;
      await TokenStorage.saveTokens(access: newAccess, refresh: refresh);
      return newAccess;
    }

    throw Exception(data.toString());
  }

  // ---------- Me (auto-refresh once) ----------
  static Future<Map<String, dynamic>> me() async {
    final response = await _getWithAuth("/auth/me/");
    final data = _decodeBody(response);

    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }
    throw Exception(data.toString());
  }

  // ---------- Logout ----------
  static Future<void> logout() async {
    await TokenStorage.clear();
  }

  // ---------- Customer: list services ----------
  static Future<List<dynamic>> listServices() async {
    final response = await _getWithAuth("/services/");
    final data = _decodeBody(response);

    if (response.statusCode == 200) return data as List<dynamic>;
    throw Exception(data.toString());
  }

  // ---------- Customer: create request ----------
  static Future<void> createRequest({
    required int serviceId,
    String note = "",
  }) async {
    final response = await _postWithAuth(
      "/requests/create/",
      body: {"service": serviceId, "note": note},
    );

    if (response.statusCode == 201) return;

    final data = _decodeBody(response);
    throw Exception(data.toString());
  }

  // ---------- Customer: my request history ----------
  static Future<List<dynamic>> myRequests() async {
    final response = await _getWithAuth("/requests/");
    final data = _decodeBody(response);

    if (response.statusCode == 200) return data as List<dynamic>;
    throw Exception(data.toString());
  }

  // ---------- Provider: incoming requests ----------
  static Future<List<dynamic>> providerIncomingRequests() async {
  String? access = await TokenStorage.getAccessToken();
  if (access == null) throw Exception("No access token. Please login.");

  final url = Uri.parse("$apiBase/requests/incoming/");
  final response = await http.get(url, headers: {"Authorization": "Bearer $access"});

  // ✅ PRINT RAW RESPONSE
  print("STATUS: ${response.statusCode}");
  print("BODY: ${response.body.substring(0, response.body.length > 400 ? 400 : response.body.length)}");

  if (response.statusCode == 401) {
    final newAccess = await refreshAccessToken();
    final retry = await http.get(url, headers: {"Authorization": "Bearer $newAccess"});

    print("RETRY STATUS: ${retry.statusCode}");
    print("RETRY BODY: ${retry.body.substring(0, retry.body.length > 400 ? 400 : retry.body.length)}");

    if (retry.statusCode != 200) {
      throw Exception("${retry.statusCode} ${retry.body}");
    }
    return jsonDecode(retry.body) as List<dynamic>;
  }

  if (response.statusCode != 200) {
    throw Exception("${response.statusCode} ${response.body}");
  }

  return jsonDecode(response.body) as List<dynamic>;
}

  // ---------- Provider: accept request ----------
  static Future<void> acceptRequest(int requestId) async {
    // MUST exist in Django urls:
    // path("requests/<int:request_id>/accept/", accept_request, ...)
    final response = await _postWithAuth("/requests/$requestId/accept/");

    if (response.statusCode == 200 || response.statusCode == 204) return;

    final data = _decodeBody(response);
    throw Exception(data.toString());
  }

  // ---------- Provider: reject request ----------
  static Future<void> rejectRequest(int requestId) async {
    // MUST exist in Django urls:
    // path("requests/<int:request_id>/reject/", reject_request, ...)
    final response = await _postWithAuth("/requests/$requestId/reject/");

    if (response.statusCode == 200 || response.statusCode == 204) return;

    final data = _decodeBody(response);
    throw Exception(data.toString());
  }
}
