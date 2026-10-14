import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/presentation/catalog_view_model.dart';

import '../../../support/widget_test_app.dart';

void main() {
  test(
    'catalog view model creates renames and deactivates all five kinds',
    () async {
      final repo = RecordingCatalogRepository();
      final vm = CatalogViewModel(catalogRepository: repo);

      await vm.createShop('新店');
      await vm.renameShop(2, '改名店');
      await vm.deactivateShop(2);
      await vm.createAccount('新账户');
      await vm.renameAccount(2, '改名账户');
      await vm.deactivateAccount(2);
      await vm.createParty('新厂家', PartyKind.supplier);
      await vm.renameParty(1, '改名厂家');
      await vm.deactivateParty(1);
      await vm.createCategory('新支出', CashDirection.expense);
      await vm.renameCategory(3, '改名支出');
      await vm.deactivateCategory(3);
      await vm.createChannel('新渠道');
      await vm.renameChannel(2, '改名渠道');
      await vm.deactivateChannel(2);

      expect(vm.shops.singleWhere((item) => item.id == 2).isActive, isFalse);
      expect(vm.accounts.singleWhere((item) => item.id == 2).isActive, isFalse);
      expect(vm.parties.singleWhere((item) => item.id == 1).isActive, isFalse);
      expect(
        vm.categories.singleWhere((item) => item.id == 3).isActive,
        isFalse,
      );
      expect(vm.channels.singleWhere((item) => item.id == 2).isActive, isFalse);
      vm.dispose();
    },
  );
  test(
    'catalog shared mutation blocks concurrent kinds and retains direct-call semantics',
    () async {
      final repo = RecordingCatalogRepository();
      final vm = CatalogViewModel(catalogRepository: repo);
      await vm.reload();
      final gate = Completer<void>();
      repo.shopWriteGate = gate.future;
      final first = vm.createShop('延迟创建');
      await Future<void>.delayed(Duration.zero);
      final blocked = vm.renameShop(1, '不应改名');
      final unrelated = vm.createAccount('不应新增账户');
      await Future<void>.delayed(Duration.zero);
      final observed = (
        repo.createShopCalls,
        repo.renameShopCalls,
        (await repo.listAccountLabels()).length,
      );
      gate.complete();
      await first;
      await blocked;
      await unrelated;
      expect(observed, (1, 0, 1));
      vm.dispose();
    },
  );

  test(
    'catalog committed caught reload error locks all mutations until successful read',
    () async {
      final repo = RecordingCatalogRepository();
      final vm = CatalogViewModel(catalogRepository: repo);
      await vm.reload();
      repo.error = Exception('刷新拒绝');
      await vm.createShop('已提交');
      expect(vm.errorMessage, contains('已保存，但刷新失败'));
      await vm.createShop('不能重复');
      await vm.deactivateShop(1);
      await vm.createAccount('不能旁路');
      expect(repo.createShopCalls, 1);
      expect(repo.deactivateShopCalls, 0);
      expect(
        (await repo
            .listAccountLabels(includeInactive: true)
            .catchError((_) => <AccountLabel>[])),
        isEmpty,
      );
      await vm.reload();
      expect(vm.errorMessage, contains('已保存，但刷新失败'));
      repo.error = null;
      await vm.reload();
      expect(vm.errorMessage, isNull);
      expect(vm.shops.any((shop) => shop.name == '已提交'), isTrue);
      expect((await repo.listAccountLabels()).length, 1);
      await vm.createShop('真正新建');
      expect(repo.createShopCalls, 2);
      vm.dispose();
    },
  );
}
