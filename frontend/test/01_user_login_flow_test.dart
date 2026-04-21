import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('01 User Login Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('sends login payload and parses successful response', () async {
      print('--- TEST START ---');
      print('Test: sends login payload and parses successful response');
      print(
          'Input Payload: {"username":"alice@example.com","password":"StrongPass123"}');
      print('Expected: token and user data should parse correctly');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'tokens': {'access': 'acc-1', 'refresh': 'ref-1'},
            'user': {'id': 11, 'role': 'customer'}
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.login(
        username: 'alice@example.com',
        password: 'StrongPass123',
      );

      // Assert
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/auth/login/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['username'], 'alice@example.com');
      expect(payload['password'], 'StrongPass123');
      expect((result['tokens'] as Map<String, dynamic>)['access'], 'acc-1');
      expect((result['user'] as Map<String, dynamic>)['role'], 'customer');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('throws readable error for invalid credentials', () async {
      print('--- TEST START ---');
      print('Test: throws readable error for invalid credentials');
      print('Input Payload: {"username":"alice@example.com","password":"bad"}');
      print(
          'Input Mock Data: {"status":401,"message":"Invalid username or password"}');
      print('Expected: should throw invalid credential error');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'Invalid username or password'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.login(username: 'alice@example.com', password: 'bad'),
        throwsA(
          predicate(
            (e) {
              print('Caught Exception: $e');
              print('Actual Result: $e');
              return e.toString().contains('Invalid username or password');
            },
          ),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('returns success wrapper for malformed success JSON', () async {
      print('--- TEST START ---');
      print('Test: returns success wrapper for malformed success JSON');
      print(
          'Input Payload: {"username":"alice@example.com","password":"StrongPass123"}');
      print('Input Mock Data: {"status":200,"body":"OK"}');
      print('Expected: should return success wrapper with raw body');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response('OK', 200);
      }));

      // Act
      final result = await ApiService.login(
        username: 'alice@example.com',
        password: 'StrongPass123',
      );
      print('Actual Result: $result');

      // Assert
      expect(result['message'], 'Success');
      expect(result['data'], 'OK');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps network failures to friendly exception', () async {
      print('--- TEST START ---');
      print('Test: maps network failures to friendly exception');
      print('Input Payload: {"username":"alice@example.com","password":"x"}');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly network error message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.login(username: 'alice@example.com', password: 'x'),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('Cannot reach backend');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });
  });
}
