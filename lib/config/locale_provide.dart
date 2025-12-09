import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:language_picker/languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider() {
    SharedPreferences.getInstance().then((preferences) {
      final locale = preferences.getString("locale") ?? "uz";
      _locale = Locale(locale);
      notifyListeners();
    });
  }

  Locale _locale = const Locale('uz');

  List<Language> get languages {
    return [Languages.uzbek, Languages.russian, Languages.english];
  }

  Locale get locale => _locale;
  Language? get language => languages.firstWhereOrNull(
        (lang) => lang.isoCode == locale.languageCode,
      );

  void setLanguage(Language language) {
    setLocale(Locale(language.isoCode));
  }

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    SharedPreferences.getInstance().then((preferences) {
      preferences.setString("locale", locale.languageCode);
    });
  }
}
