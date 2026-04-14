part of '../app_database.dart';

@DriftAccessor(tables: [Companies])
class CompanyDao extends DatabaseAccessor<AppDatabase> with _$CompanyDaoMixin {
  CompanyDao(super.db);

  Future<void> touchCompanyUpdatedAt(int id) {
    return (update(companies)..where((t) => t.id.equals(id))).write(
      CompaniesCompanion(updatedAt: Value(DateTime.now())),
    );
  }
}
