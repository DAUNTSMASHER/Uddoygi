// lib/services/language_service.dart
import 'package:flutter/material.dart';
import 'local_storage_service.dart';

class LanguageService {
  LanguageService._();
  static final LanguageService instance = LanguageService._();

  final ValueNotifier<Locale> locale = ValueNotifier(const Locale('bn'));

  bool get isBangla => locale.value.languageCode == 'bn';

  Future<void> init() async {
    final saved = await LocalStorageService.getLanguage();
    if (saved == 'en') {
      locale.value = const Locale('en');
    }
  }

  Future<void> setLanguage(String code) async {
    locale.value = Locale(code);
    await LocalStorageService.setLanguage(code);
  }
}