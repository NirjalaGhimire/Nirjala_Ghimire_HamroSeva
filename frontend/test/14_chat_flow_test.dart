import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('14 Chat Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('fetches chat threads with bearer token', () async {
      print('--- TEST START ---');
      print('Test: fetches chat threads with bearer token');
      print('Input Payload: authenticated request to /api/chat/threads/');
      print(
          'Expected: auth header should be present and one thread should return');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-1', refreshToken: 'ref-1');
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode([
            {'booking_id': 10, 'provider_name': 'Hari'}
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final threads = await ApiService.getChatThreads();

      // Assert
      expect(capturedRequest.url.path, '/api/chat/threads/');
      expect(capturedRequest.headers['authorization'], 'Bearer acc-1');
      print('Actual Result: $threads');
      expect(threads, hasLength(1));
      expect((threads.first as Map<String, dynamic>)['provider_name'], 'Hari');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('sends chat message payload and parses response', () async {
      print('--- TEST START ---');
      print('Test: sends chat message payload and parses response');
      print('Input Payload: {"bookingId":44,"message":"Hello provider"}');
      print(
          'Expected: payload should contain message and response id should be 99');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-2', refreshToken: 'ref-2');
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'id': 99, 'message': 'Hello provider'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.sendChatMessage(
        bookingId: 44,
        message: 'Hello provider',
      );

      // Assert
      expect(capturedRequest.url.path, '/api/chat/threads/44/messages/');
      expect(capturedRequest.headers['authorization'], 'Bearer acc-2');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['message'], 'Hello provider');
      expect(result['id'], 99);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('throws session-expired when chat call and refresh both return 401',
        () async {
      print('--- TEST START ---');
      print(
          'Test: throws session-expired when chat call and refresh both return 401');
      print(
          'Input Payload: chat threads request with expired access/refresh tokens');
      print(
          'Input Mock Data: /api/chat/threads/ -> 401, /api/auth/token/refresh/ -> 401');
      print(
          'Expected: should throw SessionExpiredException and clear stored tokens');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'expired-access', refreshToken: 'expired-refresh');
      ApiService.setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/chat/threads/') {
          return http.Response(
            jsonEncode({'message': 'Unauthorized'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/auth/token/refresh/') {
          return http.Response(
            jsonEncode({'message': 'Invalid refresh token'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.getChatThreads(),
        throwsA(allOf(
          isA<SessionExpiredException>(),
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return true;
          }),
        )),
      );
      final accessAfter = await TokenStorage.getAccessToken();
      final refreshAfter = await TokenStorage.getRefreshToken();
      print(
          'Actual Result: accessAfter=$accessAfter, refreshAfter=$refreshAfter');
      expect(accessAfter, isNull);
      expect(refreshAfter, isNull);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('maps chat network failure to friendly message', () async {
      print('--- TEST START ---');
      print('Test: maps chat network failure to friendly message');
      print('Input Payload: {"bookingId":1,"message":"Hi"}');
      print('Input Mock Data: SocketException("Failed host lookup")');
      print('Expected: should throw friendly backend reachability message');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-3', refreshToken: 'ref-3');
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.sendChatMessage(bookingId: 1, message: 'Hi'),
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
