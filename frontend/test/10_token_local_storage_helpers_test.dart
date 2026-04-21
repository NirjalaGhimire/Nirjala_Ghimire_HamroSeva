import 'package:flutter_test/flutter_test.dart';
import 'package:hamro_sewa_frontend/services/token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('10 Token Local Storage Helpers', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves, reads, and clears auth tokens', () async {
      print('--- TEST START ---');
      print('Test: saves, reads, and clears auth tokens');
      print(
          'Input Payload: {"accessToken":"access-1","refreshToken":"refresh-1"}');
      print(
          'Expected: saved tokens should be retrievable and null after clear');

      // Arrange
      await TokenStorage.saveTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );

      // Act
      final access = await TokenStorage.getAccessToken();
      final refresh = await TokenStorage.getRefreshToken();
      await TokenStorage.clearTokens();
      final accessAfterClear = await TokenStorage.getAccessToken();
      final refreshAfterClear = await TokenStorage.getRefreshToken();
      print(
          'Actual Result: access=$access, refresh=$refresh, accessAfterClear=$accessAfterClear, refreshAfterClear=$refreshAfterClear');

      // Assert
      expect(access, 'access-1');
      expect(refresh, 'refresh-1');
      expect(accessAfterClear, isNull);
      expect(refreshAfterClear, isNull);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('saves and restores user profile; invalid JSON returns null',
        () async {
      print('--- TEST START ---');
      print('Test: saves and restores user profile; invalid JSON returns null');
      print('Input Payload: {"id":7,"username":"ram","role":"customer"}');
      print(
          'Expected: valid user should parse, malformed stored JSON should return null');

      // Arrange
      await TokenStorage.saveUser(
          {'id': 7, 'username': 'ram', 'role': 'customer'});

      // Act
      final savedUser = await TokenStorage.getSavedUser();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile', '{bad-json');
      final malformedUser = await TokenStorage.getSavedUser();
      print(
          'Actual Result: savedUser=$savedUser, malformedUser=$malformedUser');

      // Assert
      expect(savedUser, isNotNull);
      expect(savedUser!['id'], 7);
      expect(savedUser['role'], 'customer');
      expect(malformedUser, isNull);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('returns default locale and normalizes saved locale values', () async {
      print('--- TEST START ---');
      print('Test: returns default locale and normalizes saved locale values');
      print('Input Payload: first read default, then save ne, then save fr');
      print('Expected: default en, saved ne, invalid locale fallback to en');

      // Arrange
      final localeDefault = await TokenStorage.getLocale();

      // Act
      await TokenStorage.saveLocale('ne');
      final localeNe = await TokenStorage.getLocale();
      await TokenStorage.saveLocale('fr');
      final localeFallback = await TokenStorage.getLocale();
      print(
          'Actual Result: localeDefault=$localeDefault, localeNe=$localeNe, localeFallback=$localeFallback');

      // Assert
      expect(localeDefault, 'en');
      expect(localeNe, 'ne');
      expect(localeFallback, 'en');
      print('Result: PASS');
      print('--- TEST END ---\n');
    });

    test('persists onboarding, notification, biometric and last-seen states',
        () async {
      print('--- TEST START ---');
      print(
          'Test: persists onboarding, notification, biometric and last-seen states');
      print(
          'Input Payload: onboarding=true, notifications=false, biometric=true, lastSeenId=88');
      print('Expected: all persisted preference values should match reads');

      // Arrange + Act
      await TokenStorage.setOnboardingSeen(true);
      await TokenStorage.setNotificationsEnabled(false);
      await TokenStorage.setBiometricEnabled(true);
      await TokenStorage.setLastSeenNotificationId(88);

      final onboardingSeen = await TokenStorage.getOnboardingSeen();
      final notificationsEnabled = await TokenStorage.getNotificationsEnabled();
      final biometricEnabled = await TokenStorage.getBiometricEnabled();
      final lastSeenId = await TokenStorage.getLastSeenNotificationId();
      print(
          'Actual Result: onboardingSeen=$onboardingSeen, notificationsEnabled=$notificationsEnabled, biometricEnabled=$biometricEnabled, lastSeenId=$lastSeenId');

      // Assert
      expect(onboardingSeen, true);
      expect(notificationsEnabled, false);
      expect(biometricEnabled, true);
      expect(lastSeenId, 88);
      print('Result: PASS');
      print('--- TEST END ---\n');
    });
  });
}
