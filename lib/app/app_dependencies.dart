import 'package:personal_finances_pro/core/data/ledger_database.dart';
import 'package:personal_finances_pro/core/data/ledger_privacy.dart';
import 'package:personal_finances_pro/features/catalog/data/sqlite_catalog_repository.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';
import 'package:personal_finances_pro/features/dashboard/data/sqlite_dashboard_repository.dart';
import 'package:personal_finances_pro/features/dashboard/domain/dashboard_repository.dart';
import 'package:personal_finances_pro/features/ledger/data/sqlite_cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/data/sqlite_ledger_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/cash_bill_repository.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_repository.dart';

abstract interface class AppDependenciesBootstrap {
  Future<AppDependencies> open();
}

final class AppDependencies {
  AppDependencies({
    required this.catalogRepository,
    required this.cashBillRepository,
    required this.ledgerRepository,
    required this.dashboardRepository,
    required this.close,
  });

  final CatalogRepository catalogRepository;
  final CashBillRepository cashBillRepository;
  final LedgerRepository ledgerRepository;
  final DashboardRepository dashboardRepository;
  final Future<void> Function() close;
}

final class DefaultAppDependenciesBootstrap
    implements AppDependenciesBootstrap {
  const DefaultAppDependenciesBootstrap();

  @override
  Future<AppDependencies> open() async {
    final ledgerDatabase = LedgerDatabase();
    try {
      await ledgerDatabase.open(privacy: const MethodChannelLedgerPrivacy());
      final catalogRepository = SqliteCatalogRepository(
        ledgerDatabase.database,
      );
      await catalogRepository.ensureDefaultCatalogs();
      final cashBillRepository = SqliteCashBillRepository(
        ledgerDatabase.database,
      );
      return AppDependencies(
        catalogRepository: catalogRepository,
        cashBillRepository: cashBillRepository,
        ledgerRepository: SqliteLedgerRepository(
          database: ledgerDatabase.database,
          cashBills: cashBillRepository,
        ),
        dashboardRepository: SqliteDashboardRepository(ledgerDatabase.database),
        close: ledgerDatabase.close,
      );
    } catch (_) {
      await ledgerDatabase.close();
      rethrow;
    }
  }
}
