import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables/companies.dart';
import 'tables/ledger_entries.dart';
import 'tables/settings.dart';

part 'app_database.g.dart';
part 'daos/company_dao.dart';
part 'daos/ledger_dao.dart';
part 'daos/settings_dao.dart';

@DriftDatabase(
  tables: [Companies, LedgerEntries, Settings],
  daos: [CompanyDao, LedgerDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(settings);
          }
          if (from < 3) {
            // user_version can lag behind the real schema (e.g. interrupted
            // migration); avoid duplicate ADD COLUMN errors.
            final hasStartsNewPage = await customSelect(
              "SELECT 1 FROM pragma_table_info('ledger_entries') "
              "WHERE name = 'starts_new_page' LIMIT 1",
            ).get();
            if (hasStartsNewPage.isEmpty) {
              await m.addColumn(ledgerEntries, ledgerEntries.startsNewPage);
            }
          }
          if (from < 4) {
            await customStatement(
              'CREATE INDEX IF NOT EXISTS ix_ledger_entries_company_serial '
              'ON ledger_entries (company_id, serial_number)',
            );
          }
          if (from < 5) {
            final hasPageCategory = await customSelect(
              "SELECT 1 FROM pragma_table_info('ledger_entries') "
              "WHERE name = 'page_category' LIMIT 1",
            ).get();
            if (hasPageCategory.isEmpty) {
              await m.addColumn(ledgerEntries, ledgerEntries.pageCategory);
            }
            await customStatement(
              "UPDATE ledger_entries SET page_category = "
              "(SELECT value FROM settings WHERE key = 'entry_category' LIMIT 1) "
              'WHERE id = (SELECT MIN(id) FROM ledger_entries) '
              "AND EXISTS (SELECT 1 FROM settings WHERE key = 'entry_category' "
              "AND trim(value) != '')",
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory dir;
    if (Platform.isWindows) {
      dir = await getApplicationSupportDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final file = File(p.join(dir.path, 'khata.sqlite'));
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    return NativeDatabase.createInBackground(file);
  });
}
