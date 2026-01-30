import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiService {
  // Base = your PC, from Android Emulator
  static const String baseUrl = "http://10.0.2.2:8000";
  static const String apiBase = "$baseUrl/api";

  // ---------- Existing Health Check ----------
  static Future<Map<String, dynamic>> healthCheck() async {
    final url = Uri.parse("$apiBase/health/");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception("Failed: ${response.statusCode} ${response.body}");
    }
  }

  // ---------- AUTH: Register Customer ----------
  static Future<Map<String, dynamic>> registerCustomer({
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse("$apiBase/auth/register/customer/");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "email": email,
        "phone": phone,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

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

  // ---------- AUTH: Register Provider ----------
  static Future<Map<String, dynamic>> registerProvider({
    required String username,
    required String email,
    required String phone,
    required String password,
  }) async {
    final url = Uri.parse("$apiBase/auth/register/provider/");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "email": email,
        "phone": phone,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

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

  // ---------- AUTH: Login ----------
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final url = Uri.parse("$apiBase/auth/login/");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

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

  // ---------- AUTH: Refresh Access Token ----------
  static Future<String> refreshAccessToken() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null) throw Exception("No refresh token saved");

    final url = Uri.parse("$apiBase/auth/token/refresh/");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"refresh": refresh}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["access"] != null) {
      final newAccess = data["access"] as String;
      await TokenStorage.saveTokens(access: newAccess, refresh: refresh);
      return newAccess;
    }

    throw Exception(data.toString());
  }

  // ---------- AUTH: Me (Auto-refresh once if expired) ----------
  static Future<Map<String, dynamic>> me() async {
    String? access = await TokenStorage.getAccessToken();
    if (access == null) throw Exception("No access token saved. Please login.");

    Future<http.Response> call(String token) {
      final url = Uri.parse("$apiBase/auth/me/");
      return http.get(url, headers: {"Authorization": "Bearer $token"});
    }

    var response = await call(access);

    if (response.statusCode == 401) {
      access = await refreshAccessToken();
      response = await call(access);
    }

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }

    throw Exception(data.toString());
  }

  // ---------- Logout ----------
  static Future<void> logout() async {
    await TokenStorage.clear();
  }
}
