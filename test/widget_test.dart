import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khata_management/app.dart';
import 'package:khata_management/database/app_database.dart';
import 'package:khata_management/providers/settings_provider.dart';

void main() {
  testWidgets('home screen loads', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.into(db.companies).insert(
          CompaniesCompanion(
            id: const Value(1),
            companyName: const Value('Test Company'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    final settings = SettingsProvider(db);
    await settings.load();
    await tester.pumpWidget(KhataApp(database: db, settings: settings));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await db.close();
  });
}
