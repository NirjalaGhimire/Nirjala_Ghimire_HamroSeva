import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('09 Token Refresh Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('posts refresh token and parses new access token', () async {
      print('--- TEST START ---');
      print('Test: posts refresh token and parses new access token');
      print('Input Payload: {"refresh":"refresh-123"}');
      print('Expected: refresh endpoint should return new access token');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'access': 'new-access-token'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.refreshToken(refresh: 'refresh-123');

      // Assert
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/auth/token/refresh/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['refresh'], 'refresh-123');
      expect(result['access'], 'new-access-token');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces expired refresh-token error', () async {
      print('--- TEST START ---');
      print('Test: surfaces expired refresh-token error');
      print('Input Payload: {"refresh":"expired-refresh"}');
      print(
          'Input Mock Data: {"status":401,"message":"Token is invalid or expired"}');
      print('Expected: should throw refresh-token invalid/expired message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Token is invalid or expired'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.refreshToken(refresh: 'expired-refresh'),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('Token is invalid or expired');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('returns success wrapper for malformed success JSON', () async {
      print('--- TEST START ---');
      print('Test: returns success wrapper for malformed success JSON');
      print('Input Payload: {"refresh":"refresh-123"}');
      print('Input Mock Data: {"status":200,"body":"OK"}');
      print('Expected: should return success wrapper with raw response body');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response('OK', 200);
      }));

      // Act
      final result = await ApiService.refreshToken(refresh: 'refresh-123');
      print('Actual Result: $result');

      // Assert
      expect(result['message'], 'Success');
      expect(result['data'], 'OK');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failure to readable exception', () async {
      print('--- TEST START ---');
      print('Test: maps network failure to readable exception');
      print('Input Payload: {"refresh":"refresh-123"}');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.refreshToken(refresh: 'refresh-123'),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('Cannot reach backend');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });
  });
}
