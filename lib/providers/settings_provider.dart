import 'package:flutter/material.dart';

import '../database/app_database.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._db);

  final AppDatabase _db;

  String _urduFont = 'JameelNooriNastaleeq';
  String _englishFont = 'Poppins';
  String _partyLabel = 'Party Name';
  String _value1Label = 'Value 1';
  String _value2Label = 'Value 2';
  String _value3Label = 'Value 3';
  String _pendingLabel = 'Pending';

  String get urduFont => _urduFont;
  String get englishFont => _englishFont;
  String get partyLabel => _partyLabel;
  String get value1Label => _value1Label;
  String get value2Label => _value2Label;
  String get value3Label => _value3Label;
  String get pendingLabel => _pendingLabel;

  static const String _kUrdu = 'urdu_font';
  static const String _kEnglish = 'english_font';
  static const String _kParty = 'label_party';
  static const String _kValue1 = 'label_value1';
  static const String _kValue2 = 'label_value2';
  static const String _kValue3 = 'label_value3';
  static const String _kPending = 'label_pending';

  Future<void> load() async {
    final u = await _db.settingsDao.getValue(_kUrdu);
    final e = await _db.settingsDao.getValue(_kEnglish);
    final p = await _db.settingsDao.getValue(_kParty);
    final v1 = await _db.settingsDao.getValue(_kValue1);
    final v2 = await _db.settingsDao.getValue(_kValue2);
    final v3 = await _db.settingsDao.getValue(_kValue3);
    final pe = await _db.settingsDao.getValue(_kPending);
    if (u != null) _urduFont = u;
    if (e != null) _englishFont = e;
    if (p != null) _partyLabel = p;
    if (v1 != null) _value1Label = v1;
    if (v2 != null) _value2Label = v2;
    if (v3 != null) _value3Label = v3;
    if (pe != null) _pendingLabel = pe;
    notifyListeners();
  }

  Future<void> setUrduFont(String font) async {
    _urduFont = font;
    await _db.settingsDao.setValue(_kUrdu, font);
    notifyListeners();
  }

  Future<void> setEnglishFont(String font) async {
    _englishFont = font;
    await _db.settingsDao.setValue(_kEnglish, font);
    notifyListeners();
  }

  Future<void> setPartyLabel(String value) async {
    _partyLabel = value;
    await _db.settingsDao.setValue(_kParty, value);
    notifyListeners();
  }

  Future<void> setValue1Label(String value) async {
    _value1Label = value;
    await _db.settingsDao.setValue(_kValue1, value);
    notifyListeners();
  }

  Future<void> setValue2Label(String value) async {
    _value2Label = value;
    await _db.settingsDao.setValue(_kValue2, value);
    notifyListeners();
  }

  Future<void> setValue3Label(String value) async {
    _value3Label = value;
    await _db.settingsDao.setValue(_kValue3, value);
    notifyListeners();
  }

  Future<void> setPendingLabel(String value) async {
    _pendingLabel = value;
    await _db.settingsDao.setValue(_kPending, value);
    notifyListeners();
  }
}
