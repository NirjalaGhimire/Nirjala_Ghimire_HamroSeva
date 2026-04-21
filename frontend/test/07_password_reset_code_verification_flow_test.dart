import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('07 Password Reset Code Verification Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('sends verify-reset-code payload and parses reset token', () async {
      print('--- TEST START ---');
      print('Test: sends verify-reset-code payload and parses reset token');
      print(
          'Input Payload: {"contact_value":"resetme@example.com","is_email":true,"code":"998877"}');
      print(
          'Expected: request payload should match and reset token should parse');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'reset_token': 'rst-123'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.verifyResetCode(
        contactValue: 'resetme@example.com',
        isEmail: true,
        code: '998877',
      );

      // Assert
      expect(capturedRequest.url.path, '/api/auth/verify-reset-code/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['contact_value'], 'resetme@example.com');
      expect(payload['is_email'], true);
      expect(payload['code'], '998877');
      expect(result['reset_token'], 'rst-123');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces incorrect reset code errors', () async {
      print('--- TEST START ---');
      print('Test: surfaces incorrect reset code errors');
      print(
          'Input Payload: {"contact_value":"resetme@example.com","is_email":true,"code":"111111"}');
      print(
          'Input Mock Data: {"status":400,"message":"Invalid verification code"}');
      print('Expected: should throw invalid verification code message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Invalid verification code'}),
          400,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.verifyResetCode(
          contactValue: 'resetme@example.com',
          isEmail: true,
          code: '111111',
        ),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('Invalid verification code');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces expired code errors', () async {
      print('--- TEST START ---');
      print('Test: surfaces expired code errors');
      print(
          'Input Payload: {"contact_value":"9800000000","is_email":false,"code":"998877"}');
      print(
          'Input Mock Data: {"status":410,"message":"Verification code expired"}');
      print('Expected: should throw verification code expired message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Verification code expired'}),
          410,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.verifyResetCode(
          contactValue: '9800000000',
          isEmail: false,
          code: '998877',
        ),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('Verification code expired');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failures to friendly text', () async {
      print('--- TEST START ---');
      print('Test: maps network failures to friendly text');
      print(
          'Input Payload: {"contact_value":"resetme@example.com","is_email":true,"code":"998877"}');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.verifyResetCode(
          contactValue: 'resetme@example.com',
          isEmail: true,
          code: '998877',
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
