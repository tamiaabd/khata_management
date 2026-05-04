import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:khata_management/database/app_database.dart';
import 'package:khata_management/providers/settings_provider.dart';
import 'package:khata_management/screens/home_screen.dart';
import 'package:khata_management/utils/ledger_totals.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home screen loads', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    await db
        .into(db.companies)
        .insert(
          CompaniesCompanion(
            id: const Value(1),
            companyName: const Value('Test Company'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    final settings = SettingsProvider(db);
    await settings.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.text('PAGE TOTAL'), findsOneWidget);
    expect(find.text('TOTAL'), findsNWidgets(3));
    expect(find.text('GODAM'), findsOneWidget);
    expect(find.text('GRAND TOTAL'), findsOneWidget);
    await db.close();
  });

  testWidgets('godam values are saved in settings', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final settings = SettingsProvider(db);
    await settings.load();

    await settings.setGodamTotals(
      const LedgerTotals(pending: 1, value1: 2, value2: 3, value3: 4),
    );

    final reloaded = SettingsProvider(db);
    await reloaded.load();

    expect(
      reloaded.godamTotals,
      const LedgerTotals(pending: 1, value1: 2, value2: 3, value3: 4),
    );
    await db.close();
  });
}
