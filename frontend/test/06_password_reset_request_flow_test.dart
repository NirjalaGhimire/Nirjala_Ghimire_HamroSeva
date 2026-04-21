import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('06 Password Reset Request Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('sends trimmed email and parses forgot-password success', () async {
      print('--- TEST START ---');
      print('Test: sends trimmed email and parses forgot-password success');
      print('Input Payload: {"email":" resetme@example.com "}');
      print('Expected: email should be trimmed and success message parsed');

      // Arrange
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'message': 'Reset code sent'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.requestPasswordReset(
        email: ' resetme@example.com ',
      );

      // Assert
      expect(capturedRequest.url.path, '/api/auth/forgot-password/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['email'], 'resetme@example.com');
      expect(result['message'], 'Reset code sent');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces unknown-email backend error', () async {
      print('--- TEST START ---');
      print('Test: surfaces unknown-email backend error');
      print('Input Payload: {"email":"missing@example.com"}');
      print(
          'Input Mock Data: {"status":404,"message":"User with this email does not exist"}');
      print('Expected: should throw unknown email backend message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({'message': 'User with this email does not exist'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.requestPasswordReset(email: 'missing@example.com'),
        throwsA(
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return e.toString().contains('User with this email does not exist');
          }),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('returns success wrapper for non-JSON success payload', () async {
      print('--- TEST START ---');
      print('Test: returns success wrapper for non-JSON success payload');
      print('Input Payload: {"email":"resetme@example.com"}');
      print('Input Mock Data: {"status":200,"body":"queued"}');
      print('Expected: should return success wrapper with raw body');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response('queued', 200);
      }));

      // Act
      final result = await ApiService.requestPasswordReset(
        email: 'resetme@example.com',
      );
      print('Actual Result: $result');

      // Assert
      expect(result['message'], 'Success');
      expect(result['data'], 'queued');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps timeout or network error to readable exception', () async {
      print('--- TEST START ---');
      print('Test: maps timeout or network error to readable exception');
      print('Input Payload: {"email":"resetme@example.com"}');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.requestPasswordReset(email: 'resetme@example.com'),
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
