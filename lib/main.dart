import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'app.dart';
import 'database/app_database.dart';
import 'providers/settings_provider.dart';

/// In-app updates: [AppUpdateService] + [SplashScreen] (`checkUpdateFlag`, `checkForUpdates`).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  final db = AppDatabase();
  await _ensureDefaultCompany(db);
  await _ensureDefaultFonts(db);
  await _ensureInstallationId(db);
  final settings = SettingsProvider(db);
  await settings.load();
  runApp(KhataApp(database: db, settings: settings));
}

Future<void> _ensureDefaultCompany(AppDatabase db) async {
  final existing = await (db.select(db.companies)
        ..where((t) => t.id.equals(1)))
      .getSingleOrNull();
  if (existing == null) {
    await db.into(db.companies).insert(
          CompaniesCompanion(
            id: const Value(1),
            companyName: const Value('My Company'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}

Future<void> _ensureDefaultFonts(AppDatabase db) async {
  final urdu = await db.settingsDao.getValue('urdu_font');
  if (urdu == null) {
    await db.settingsDao.setValue('urdu_font', 'JameelNooriNastaleeq');
  }
  final english = await db.settingsDao.getValue('english_font');
  if (english == null) {
    await db.settingsDao.setValue('english_font', 'Poppins');
  }
}

Future<void> _ensureInstallationId(AppDatabase db) async {
  const key = 'installation_id';
  final existing = await db.settingsDao.getValue(key);
  if (existing != null && existing.trim().isNotEmpty) {
    return;
  }
  await db.settingsDao.setValue(key, _generateInstallationId());
}

String _generateInstallationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final b = bytes.map(hex).toList();
  return '${b[0]}${b[1]}${b[2]}${b[3]}-'
      '${b[4]}${b[5]}-'
      '${b[6]}${b[7]}-'
      '${b[8]}${b[9]}-'
      '${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
}
