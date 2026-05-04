import 'package:flutter/material.dart';

import '../database/app_database.dart';
import '../utils/ledger_totals.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._db);

  final AppDatabase _db;

  String _urduFont = 'JameelNooriNastaleeq';
  String _englishFont = 'Poppins';
  String _value1Label = 'Value 1';
  String _value2Label = 'Value 2';
  String _value3Label = 'Value 3';
  LedgerTotals _godamTotals = LedgerTotals.zero;
  Future<void> _godamWriteQueue = Future<void>.value();

  String get urduFont => _urduFont;
  String get englishFont => _englishFont;
  String get value1Label => _value1Label;
  String get value2Label => _value2Label;
  String get value3Label => _value3Label;
  LedgerTotals get godamTotals => _godamTotals;

  static const String _kUrdu = 'urdu_font';
  static const String _kEnglish = 'english_font';
  static const String _kValue1 = 'label_value1';
  static const String _kValue2 = 'label_value2';
  static const String _kValue3 = 'label_value3';
  static const String _kGodamPending = 'godam_pending';
  static const String _kGodamValue1 = 'godam_value1';
  static const String _kGodamValue2 = 'godam_value2';
  static const String _kGodamValue3 = 'godam_value3';
  static const Set<String> _supportedUrduFonts = {
    'BombayBlackUnicode',
    'JameelNooriNastaleeq',
    'JameelNooriNastaleeqKasheeda',
  };

  Future<void> load() async {
    final u = await _db.settingsDao.getValue(_kUrdu);
    final e = await _db.settingsDao.getValue(_kEnglish);
    final v1 = await _db.settingsDao.getValue(_kValue1);
    final v2 = await _db.settingsDao.getValue(_kValue2);
    final v3 = await _db.settingsDao.getValue(_kValue3);
    final gp = await _db.settingsDao.getValue(_kGodamPending);
    final gv1 = await _db.settingsDao.getValue(_kGodamValue1);
    final gv2 = await _db.settingsDao.getValue(_kGodamValue2);
    final gv3 = await _db.settingsDao.getValue(_kGodamValue3);
    if (u != null) {
      final migrated = _normalizeUrduFont(u);
      _urduFont = migrated;
      if (migrated != u) {
        await _db.settingsDao.setValue(_kUrdu, migrated);
      }
    }
    if (e != null) _englishFont = e;
    if (v1 != null) _value1Label = v1;
    if (v2 != null) _value2Label = v2;
    if (v3 != null) _value3Label = v3;
    _godamTotals = LedgerTotals(
      pending: _parseStoredDouble(gp),
      value1: _parseStoredDouble(gv1),
      value2: _parseStoredDouble(gv2),
      value3: _parseStoredDouble(gv3),
    );
    notifyListeners();
  }

  Future<void> setUrduFont(String font) async {
    final normalized = _normalizeUrduFont(font);
    _urduFont = normalized;
    await _db.settingsDao.setValue(_kUrdu, normalized);
    notifyListeners();
  }

  Future<void> setEnglishFont(String font) async {
    _englishFont = font;
    await _db.settingsDao.setValue(_kEnglish, font);
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

  Future<void> setGodamTotals(LedgerTotals value) {
    _godamTotals = value;
    notifyListeners();

    final write = _godamWriteQueue.then((_) async {
      await Future.wait([
        _db.settingsDao.setValue(_kGodamPending, value.pending.toString()),
        _db.settingsDao.setValue(_kGodamValue1, value.value1.toString()),
        _db.settingsDao.setValue(_kGodamValue2, value.value2.toString()),
        _db.settingsDao.setValue(_kGodamValue3, value.value3.toString()),
      ]);
    });
    _godamWriteQueue = write.catchError((_) {});
    return write;
  }

  double _parseStoredDouble(String? value) {
    if (value == null) return 0;
    return double.tryParse(value.trim()) ?? 0;
  }

  String _normalizeUrduFont(String raw) {
    if (_supportedUrduFonts.contains(raw)) return raw;
    if (raw == 'BobyBlack' || raw == 'NotoNastaliqUrdu') {
      return 'JameelNooriNastaleeq';
    }
    // Migrate old stored values to current supported font.
    return 'JameelNooriNastaleeq';
  }
}
