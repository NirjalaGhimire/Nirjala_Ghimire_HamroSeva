import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('04 Registration OTP Send Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('merges role into payload and parses send-otp success', () async {
      print('--- TEST START ---');
      print('Test: merges role into payload and parses send-otp success');
      print(
          'Input Payload: {"role":"customer","email":"ram@example.com","username":"ram"}');
      print(
          'Expected: role should be merged and OTP success message should return');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'OTP sent successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.sendRegistrationOtp(
        role: 'customer',
        body: {
          'email': 'ram@example.com',
          'username': 'ram',
        },
      );

      // Assert
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/auth/register/send-otp/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['email'], 'ram@example.com');
      expect(payload['username'], 'ram');
      expect(payload['role'], 'customer');
      expect(result['message'], 'OTP sent successfully');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces invalid email errors from backend', () async {
      print('--- TEST START ---');
      print('Test: surfaces invalid email errors from backend');
      print('Input Payload: {"role":"customer","email":"bad-email"}');
      print(
          'Input Mock Data: {"status":400,"message":"Invalid email address"}');
      print('Expected: should throw invalid email error');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Invalid email address'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.sendRegistrationOtp(
          role: 'customer',
          body: {'email': 'bad-email'},
        ),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('Invalid email address');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('returns success wrapper if success body is not JSON', () async {
      print('--- TEST START ---');
      print('Test: returns success wrapper if success body is not JSON');
      print('Input Payload: {"role":"provider","email":"shop@example.com"}');
      print('Input Mock Data: {"status":200,"body":"OTP queued"}');
      print('Expected: should return success wrapper with raw body');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response('OTP queued', 200);
      }));

      // Act
      final result = await ApiService.sendRegistrationOtp(
        role: 'provider',
        body: {'email': 'shop@example.com'},
      );
      print('Actual Result: $result');

      // Assert
      expect(result['message'], 'Success');
      expect(result['data'], 'OTP queued');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failures to user-friendly text', () async {
      print('--- TEST START ---');
      print('Test: maps network failures to user-friendly text');
      print('Input Payload: {"role":"provider","email":"shop@example.com"}');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly backend reachability error');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.sendRegistrationOtp(
          role: 'provider',
          body: {'email': 'shop@example.com'},
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
