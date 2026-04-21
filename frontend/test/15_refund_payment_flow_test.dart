import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('15 Refund and Payment Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('initiates payment with numeric booking id and amount', () async {
      print('--- TEST START ---');
      print('Test: initiates payment with numeric booking id and amount');
      print('Input Payload: {"bookingId":"123","amount":1500.0}');
      print(
          'Expected: booking_id should be numeric and transaction id should parse');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-pay', refreshToken: 'ref-pay');
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'payment_url': 'https://esewa.example/pay/abc',
            'transaction_id': 'TX-123',
            'amount': 1500.0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.initiatePayment(
        bookingId: '123',
        amount: 1500.0,
      );

      // Assert
      expect(capturedRequest.url.path, '/api/payments/initiate/');
      expect(capturedRequest.headers['authorization'], 'Bearer acc-pay');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['booking_id'], 123);
      expect(payload['amount'], 1500.0);
      expect(result['transaction_id'], 'TX-123');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('submits provider refund review action with optional note', () async {
      print('--- TEST START ---');
      print('Test: submits provider refund review action with optional note');
      print(
          'Input Payload: {"refundId":55,"action":"approve","note":" valid case "}');
      print(
          'Expected: note should be trimmed and approved status should parse');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-r1', refreshToken: 'ref-r1');
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'status': 'approved'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.providerReviewRefund(
        refundId: 55,
        action: 'approve',
        note: ' valid case ',
      );

      // Assert
      expect(capturedRequest.url.path, '/api/refunds/55/provider-review/');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['action'], 'approve');
      expect(payload['note'], 'valid case');
      expect(result['status'], 'approved');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('submits admin refund review and fetches refunds list', () async {
      print('--- TEST START ---');
      print('Test: submits admin refund review and fetches refunds list');
      print(
          'Input Payload: {"review":{"refundId":9,"action":"approve","refundReference":"ESW-REF-1"}}');
      print(
          'Expected: review should be approved and refunds list should contain id=9');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-admin', refreshToken: 'ref-admin');
      var reviewCalled = false;
      ApiService.setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/refunds/9/review/') {
          reviewCalled = true;
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['action'], 'approve');
          expect(payload['refund_reference'], 'ESW-REF-1');
          return http.Response(
            jsonEncode({'status': 'approved'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/refunds/') {
          return http.Response(
            jsonEncode([
              {'id': 9, 'status': 'approved'}
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      }));

      // Act
      final reviewResult = await ApiService.reviewRefund(
        refundId: 9,
        action: 'approve',
        refundReference: 'ESW-REF-1',
      );
      final refunds = await ApiService.getRefunds();
      print('Actual Result: reviewResult=$reviewResult, refunds=$refunds');

      // Assert
      expect(reviewCalled, true);
      expect(reviewResult['status'], 'approved');
      expect(refunds, hasLength(1));
      expect((refunds.first as Map<String, dynamic>)['id'], 9);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces payment/refund API failures and network failures', () async {
      print('--- TEST START ---');
      print('Test: surfaces payment/refund API failures and network failures');
      print(
          'Input Payload: initiatePayment {"bookingId":"3","amount":500} then getRefunds');
      print(
          'Input Mock Data: payment -> 503 Payment gateway unavailable; refunds -> SocketException');
      print(
          'Expected: payment should throw gateway error and refunds should throw friendly network message');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-fail', refreshToken: 'ref-fail');
      ApiService.setHttpClient(MockClient((request) async {
        if (request.url.path == '/api/payments/initiate/') {
          return http.Response(
            jsonEncode({'message': 'Payment gateway unavailable'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        throw const SocketException('Failed host lookup');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.initiatePayment(bookingId: '3', amount: 500),
        throwsA(
          predicate((e) {
            print('Caught Exception (Payment): $e');
            print('Actual Result (Payment): $e');
            return e.toString().contains('Payment gateway unavailable');
          }),
        ),
      );
      await expectLater(
        () => ApiService.getRefunds(),
        throwsA(predicate((e) {
          print('Caught Exception (Refunds): $e');
          print('Actual Result (Refunds): $e');
          return e.toString().contains('Cannot reach backend');
        })),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });
  });
}
