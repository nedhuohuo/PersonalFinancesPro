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
}
