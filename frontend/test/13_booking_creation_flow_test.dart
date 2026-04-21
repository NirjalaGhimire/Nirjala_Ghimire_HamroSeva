import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/api_service.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('13 Booking Creation Flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ApiService.resetTestState();
      ApiService.setApiBaseForTesting('http://test.local/api');
    });

    tearDown(() {
      ApiService.setHttpClient(http.Client());
      ApiService.resetTestState();
    });

    test('sends booking payload with auth header and rounded coordinates',
        () async {
      print('--- TEST START ---');
      print(
          'Test: sends booking payload with auth header and rounded coordinates');
      print(
          'Input Payload: {"serviceId":77,"bookingDate":"2026-01-20","bookingTime":"10:30:00","totalAmount":1200.5,"address":"Kathmandu","latitude":27.7001234567,"longitude":85.3331234567}');
      print(
          'Expected: booking payload should include auth header and rounded coordinates');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-123', refreshToken: 'ref-123');
      late http.Request capturedRequest;
      ApiService.setHttpClient(MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({'id': 501, 'status': 'pending'}),
          201,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act
      final result = await ApiService.createBooking(
        serviceId: 77,
        bookingDate: '2026-01-20',
        bookingTime: '10:30:00',
        notes: 'Need urgent support',
        totalAmount: 1200.5,
        address: 'Kathmandu',
        latitude: 27.7001234567,
        longitude: 85.3331234567,
        requestImageUrl: 'https://img.example.com/req.jpg',
      );

      // Assert
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/api/bookings/create/');
      expect(capturedRequest.headers['authorization'], 'Bearer acc-123');
      final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      print('Actual Result: $result');
      print('Parsed Request Payload: $payload');
      expect(payload['service'], 77);
      expect(payload['booking_date'], '2026-01-20');
      expect(payload['booking_time'], '10:30:00');
      expect(payload['total_amount'], '1200.50');
      expect(payload['latitude'], closeTo(27.70012346, 0.000000001));
      expect(payload['longitude'], closeTo(85.33312346, 0.000000001));
      expect(payload['request_image_url'], 'https://img.example.com/req.jpg');
      expect(result['status'], 'pending');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('surfaces unauthorized booking creation response', () async {
      print('--- TEST START ---');
      print('Test: surfaces unauthorized booking creation response');
      print(
          'Input Payload: {"serviceId":77,"bookingDate":"2026-01-20","bookingTime":"10:30:00","totalAmount":500}');
      print(
          'Input Mock Data: {"status":401,"message":"Authentication credentials were not provided"}');
      print('Expected: should throw unauthorized booking creation message');

      // Arrange
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode(
              {'message': 'Authentication credentials were not provided'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.createBooking(
          serviceId: 77,
          bookingDate: '2026-01-20',
          bookingTime: '10:30:00',
          totalAmount: 500,
        ),
        throwsA(
          predicate(
            (e) {
              print('Caught Exception: $e');
              print('Actual Result: $e');
              return e
                  .toString()
                  .contains('Authentication credentials were not provided');
            },
          ),
        ),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('returns success wrapper for malformed success response', () async {
      print('--- TEST START ---');
      print('Test: returns success wrapper for malformed success response');
      print(
          'Input Payload: {"serviceId":77,"bookingDate":"2026-01-20","bookingTime":"10:30:00","totalAmount":500}');
      print('Input Mock Data: {"status":201,"body":"created"}');
      print('Expected: should return success wrapper with raw body');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-123', refreshToken: 'ref-123');
      ApiService.setHttpClient(MockClient((_) async {
        return http.Response('created', 201);
      }));

      // Act
      final result = await ApiService.createBooking(
        serviceId: 77,
        bookingDate: '2026-01-20',
        bookingTime: '10:30:00',
        totalAmount: 500,
      );
      print('Actual Result: $result');

      // Assert
      expect(result['message'], 'Success');
      expect(result['data'], 'created');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('propagates network exceptions from booking request', () async {
      print('--- TEST START ---');
      print('Test: propagates network exceptions from booking request');
      print(
          'Input Payload: {"serviceId":77,"bookingDate":"2026-01-20","bookingTime":"10:30:00","totalAmount":500}');
      print('Input Mock Data: SocketException("Connection reset by peer")');
      print('Expected: should throw SocketException');

      // Arrange
      await TokenStorage.saveTokens(
          accessToken: 'acc-123', refreshToken: 'ref-123');
      ApiService.setHttpClient(MockClient((_) async {
        throw const SocketException('Connection reset by peer');
      }));

      // Act + Assert
      await expectLater(
        () => ApiService.createBooking(
          serviceId: 77,
          bookingDate: '2026-01-20',
          bookingTime: '10:30:00',
          totalAmount: 500,
        ),
        throwsA(allOf(
          isA<SocketException>(),
          predicate((e) {
            print('Caught Exception: $e');
            print('Actual Result: $e');
            return true;
          }),
        )),
      );
      print('Result: PASS');
      print('--- TEST END ---\n');
    });
  });
}
