import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('05 Registration OTP Verify Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('sends normalized verify-otp payload and parses success', () async {
      print('--- TEST START ---');
      print('Test: sends normalized verify-otp payload and parses success');
      print(
          'Input Payload: {"email":" user@example.com ","role":" Provider ","code":" 123456 "}');
      print(
          'Expected: email/role/code should be normalized and response parsed');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'OTP verified'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.verifyRegistrationOtp(
        email: ' user@example.com ',
        role: ' Provider ',
        code: ' 123456 ',
      );

      // Assert
      expect(capturedRequest.url.path, '/api/auth/register/verify-otp/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['email'], 'user@example.com');
      expect(payload['role'], 'provider');
      expect(payload['code'], '123456');
      expect(result['message'], 'OTP verified');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces invalid OTP errors', () async {
      print('--- TEST START ---');
      print('Test: surfaces invalid OTP errors');
      print(
          'Input Payload: {"email":"user@example.com","role":"provider","code":"000000"}');
      print('Input Mock Data: {"status":400,"message":"Invalid OTP code"}');
      print('Expected: should throw invalid OTP code message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Invalid OTP code'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.verifyRegistrationOtp(
          email: 'user@example.com',
          role: 'provider',
          code: '000000',
        ),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('Invalid OTP code');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces expired OTP errors', () async {
      print('--- TEST START ---');
      print('Test: surfaces expired OTP errors');
      print(
          'Input Payload: {"email":"user@example.com","role":"customer","code":"123456"}');
      print('Input Mock Data: {"status":410,"message":"OTP expired"}');
      print('Expected: should throw OTP expired message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'OTP expired'}),
          410,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.verifyRegistrationOtp(
          email: 'user@example.com',
          role: 'customer',
          code: '123456',
        ),
        throwsA(predicate((e) {
          print('Caught Exception: $e');
          print('Actual Result: $e');
          return e.toString().contains('OTP expired');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failure to friendly error', () async {
      print('--- TEST START ---');
      print('Test: maps network failure to friendly error');
      print(
          'Input Payload: {"email":"user@example.com","role":"customer","code":"123456"}');
      print('Input Mock Data: SocketException("Network is unreachable")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Network is unreachable');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.verifyRegistrationOtp(
          email: 'user@example.com',
          role: 'customer',
          code: '123456',
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
