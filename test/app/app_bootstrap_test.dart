import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/app/app.dart';
import 'package:personal_finances_pro/app/app_dependencies.dart';

final class FailingBootstrap implements AppDependenciesBootstrap {
  @override
  Future<AppDependencies> open() =>
      Future<AppDependencies>.error(Exception('无法确认账本已排除系统自动备份'));
}

void main() {
  testWidgets('privacy setup failure blocks ledger pages with clear error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShopLedgerApp(dependenciesBootstrap: FailingBootstrap()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('无法确认账本已排除系统自动备份'), findsOneWidget);
    expect(find.text('新增现金账'), findsNothing);
  });
}
