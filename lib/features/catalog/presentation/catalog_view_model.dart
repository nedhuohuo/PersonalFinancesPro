import 'package:flutter/foundation.dart' hide Category;
import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/catalog/domain/catalog_repository.dart';

enum CatalogKind { shops, accounts, parties, categories, channels }

final class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel({required CatalogRepository catalogRepository})
    : _catalogRepository = catalogRepository;

  final CatalogRepository _catalogRepository;
  var _disposed = false;

  bool isLoading = false;
  String? errorMessage;
  List<Shop> shops = const [];
  List<AccountLabel> accounts = const [];
  List<Party> parties = const [];
  List<Category> categories = const [];
  List<ResaleChannel> channels = const [];

  Future<void> reload() async {
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      shops = await _catalogRepository.listShops(includeInactive: true);
      accounts = await _catalogRepository.listAccountLabels(
        includeInactive: true,
      );
      parties = await _catalogRepository.listParties(includeInactive: true);
      categories = await _catalogRepository.listCategories(
        includeInactive: true,
      );
      channels = await _catalogRepository.listResaleChannels(
        includeInactive: true,
      );
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> createShop(String name) =>
      _mutate(() => _catalogRepository.createShop(name: _requiredName(name)));
  Future<void> renameShop(int id, String name) => _mutate(
    () => _catalogRepository.renameShop(id: id, name: _requiredName(name)),
  );
  Future<void> deactivateShop(int id) =>
      _mutate(() => _catalogRepository.deactivateShop(id));

  Future<void> createAccount(String name) => _mutate(
    () => _catalogRepository.createAccountLabel(name: _requiredName(name)),
  );
  Future<void> renameAccount(int id, String name) => _mutate(
    () => _catalogRepository.renameAccountLabel(
      id: id,
      name: _requiredName(name),
    ),
  );
  Future<void> deactivateAccount(int id) =>
      _mutate(() => _catalogRepository.deactivateAccountLabel(id));

  Future<void> createParty(String name, PartyKind kind) => _mutate(
    () => _catalogRepository.createParty(name: _requiredName(name), kind: kind),
  );
  Future<void> renameParty(int id, String name) => _mutate(
    () => _catalogRepository.renameParty(id: id, name: _requiredName(name)),
  );
  Future<void> deactivateParty(int id) =>
      _mutate(() => _catalogRepository.deactivateParty(id));

  Future<void> createCategory(String name, CashDirection direction) => _mutate(
    () => _catalogRepository.createCategory(
      name: _requiredName(name),
      direction: direction,
    ),
  );
  Future<void> renameCategory(int id, String name) => _mutate(
    () => _catalogRepository.renameCategory(id: id, name: _requiredName(name)),
  );
  Future<void> deactivateCategory(int id) =>
      _mutate(() => _catalogRepository.deactivateCategory(id));

  Future<void> createChannel(String name) => _mutate(
    () => _catalogRepository.createResaleChannel(name: _requiredName(name)),
  );
  Future<void> renameChannel(int id, String name) => _mutate(
    () => _catalogRepository.renameResaleChannel(
      id: id,
      name: _requiredName(name),
    ),
  );
  Future<void> deactivateChannel(int id) =>
      _mutate(() => _catalogRepository.deactivateResaleChannel(id));

  Future<void> _mutate(Future<Object?> Function() action) async {
    errorMessage = null;
    _notify();
    try {
      await action();
      await reload();
    } catch (error) {
      errorMessage = error.toString();
      _notify();
    }
  }

  String _requiredName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const FormatException('名称不能为空');
    return trimmed;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

String catalogKindTitle(CatalogKind kind) => switch (kind) {
  CatalogKind.shops => '店铺',
  CatalogKind.accounts => '账户',
  CatalogKind.parties => '往来方',
  CatalogKind.categories => '分类',
  CatalogKind.channels => '渠道',
};
