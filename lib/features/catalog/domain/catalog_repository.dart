import 'catalog_models.dart';

abstract interface class CatalogRepository {
  Future<void> ensureDefaultCatalogs();
  Future<List<Shop>> listShops({bool includeInactive = false});
  Future<Shop> createShop({required String name});
  Future<Shop> renameShop({required int id, required String name});
  Future<void> deactivateShop(int id);

  Future<List<AccountLabel>> listAccountLabels({bool includeInactive = false});
  Future<AccountLabel> createAccountLabel({required String name});
  Future<AccountLabel> renameAccountLabel({
    required int id,
    required String name,
  });
  Future<void> deactivateAccountLabel(int id);

  Future<List<Party>> listParties({
    PartyKind? kind,
    bool includeInactive = false,
  });
  Future<Party> createParty({required String name, required PartyKind kind});
  Future<Party> renameParty({required int id, required String name});
  Future<void> deactivateParty(int id);

  Future<List<Category>> listCategories({
    CashDirection? direction,
    CategoryRole? role,
    bool includeInactive = false,
  });
  Future<Category> createCategory({
    required String name,
    required CashDirection direction,
  });
  Future<Category> renameCategory({required int id, required String name});
  Future<void> deactivateCategory(int id);

  Future<List<ResaleChannel>> listResaleChannels({
    bool includeInactive = false,
  });
  Future<ResaleChannel> createResaleChannel({required String name});
  Future<ResaleChannel> renameResaleChannel({
    required int id,
    required String name,
  });
  Future<void> deactivateResaleChannel(int id);
}
