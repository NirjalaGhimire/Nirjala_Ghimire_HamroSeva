import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('08 Set New Password Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('posts reset token and new password, then parses success', () async {
      print('--- TEST START ---');
      print('Test: posts reset token and new password, then parses success');
      print(
          'Input Payload: {"reset_token":"rst-abc","new_password":"StrongPass123!"}');
      print(
          'Expected: set-new-password endpoint should parse success response');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Password changed successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.setNewPassword(
        resetToken: 'rst-abc',
        newPassword: 'StrongPass123!',
      );

      // Assert
      expect(capturedRequest.url.path, '/api/auth/set-new-password/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['reset_token'], 'rst-abc');
      expect(payload['new_password'], 'StrongPass123!');
      expect(result['message'], 'Password changed successfully');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces invalid reset token response', () async {
      print('--- TEST START ---');
      print('Test: surfaces invalid reset token response');
      print(
          'Input Payload: {"reset_token":"bad-token","new_password":"StrongPass123!"}');
      print(
          'Input Mock Data: {"status":400,"message":"Invalid or expired reset token"}');
      print('Expected: should throw invalid or expired reset token message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Invalid or expired reset token'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.setNewPassword(
          resetToken: 'bad-token',
          newPassword: 'StrongPass123!',
        ),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('Invalid or expired reset token');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces weak-password backend validation', () async {
      print('--- TEST START ---');
      print('Test: surfaces weak-password backend validation');
      print('Input Payload: {"reset_token":"rst-abc","new_password":"123"}');
      print('Input Mock Data: {"status":400,"message":"Password is too weak"}');
      print('Expected: should throw weak password validation message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Password is too weak'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.setNewPassword(
          resetToken: 'rst-abc',
          newPassword: '123',
        ),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('Password is too weak');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failures to friendly error', () async {
      print('--- TEST START ---');
      print('Test: maps network failures to friendly error');
      print(
          'Input Payload: {"reset_token":"rst-abc","new_password":"StrongPass123!"}');
      print('Input Mock Data: SocketException("Network is unreachable")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Network is unreachable');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.setNewPassword(
          resetToken: 'rst-abc',
          newPassword: 'StrongPass123!',
        ),
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
