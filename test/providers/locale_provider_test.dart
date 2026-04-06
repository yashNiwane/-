import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitwardhini/providers/locale_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocaleProvider Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initial locale should be English', () {
      final provider = LocaleProvider();
      expect(provider.locale, const Locale('en'));
    });

    test('Setting locale should update state and persistence', () async {
      final provider = LocaleProvider();

      provider.setLocale(const Locale('mr'));
      expect(provider.locale, const Locale('mr'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language_code'), 'mr');
    });

    test('Setting invalid locale should not update state', () async {
      final provider = LocaleProvider();

      provider.setLocale(const Locale('fr'));
      expect(provider.locale, const Locale('en'));
    });
  });
}
