import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'app.dart';
import 'database/app_database.dart';
import 'providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  final db = AppDatabase();
  await _ensureDefaultCompany(db);
  await _ensureDefaultFonts(db);
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
