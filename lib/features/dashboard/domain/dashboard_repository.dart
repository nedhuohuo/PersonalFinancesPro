import 'package:personal_finances_pro/core/domain/local_date.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';

import 'dashboard_snapshots.dart';

abstract interface class DashboardRepository {
  Future<DashboardSnapshot> loadDashboardSnapshot({
    required LocalDate monthStart,
    required LocalDate monthEnd,
    BusinessScope? scope,
  });
  Future<LedgerDetailSnapshot> loadLedgerDetailSnapshot({
    required LocalDate startDate,
    required LocalDate endDate,
    BusinessScope? scope,
  });
}
