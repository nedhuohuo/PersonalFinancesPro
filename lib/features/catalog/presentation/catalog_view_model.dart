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
  bool isSaving = false;
  bool _refreshRequired = false;

  bool get canMutate =>
      !_disposed && !isLoading && !isSaving && !_refreshRequired;
  String? errorMessage;
  List<Shop> shops = const [];
  List<AccountLabel> accounts = const [];
  List<Party> parties = const [];
  List<Category> categories = const [];
  List<ResaleChannel> channels = const [];

  Future<bool> reload() async {
    if (_disposed || isSaving || isLoading) return false;
    return _reload();
  }

  Future<bool> _reload() async {
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
      _refreshRequired = false;
      return true;
    } catch (error) {
      errorMessage = '${_refreshRequired ? '已保存，但刷新失败：' : ''}$error';
      return false;
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<bool> createShop(String name) =>
      _mutate(() => _catalogRepository.createShop(name: _requiredName(name)));
  Future<bool> renameShop(int id, String name) => _mutate(
    () => _catalogRepository.renameShop(id: id, name: _requiredName(name)),
  );
  Future<bool> deactivateShop(int id) =>
      _mutate(() => _catalogRepository.deactivateShop(id));

  Future<bool> createAccount(String name) => _mutate(
    () => _catalogRepository.createAccountLabel(name: _requiredName(name)),
  );
  Future<bool> renameAccount(int id, String name) => _mutate(
    () => _catalogRepository.renameAccountLabel(
      id: id,
      name: _requiredName(name),
    ),
  );
  Future<bool> deactivateAccount(int id) =>
      _mutate(() => _catalogRepository.deactivateAccountLabel(id));

  Future<bool> createParty(String name, PartyKind kind) => _mutate(
    () => _catalogRepository.createParty(name: _requiredName(name), kind: kind),
  );
  Future<bool> renameParty(int id, String name) => _mutate(
    () => _catalogRepository.renameParty(id: id, name: _requiredName(name)),
  );
  Future<bool> deactivateParty(int id) =>
      _mutate(() => _catalogRepository.deactivateParty(id));

  Future<bool> createCategory(String name, CashDirection direction) => _mutate(
    () => _catalogRepository.createCategory(
      name: _requiredName(name),
      direction: direction,
    ),
  );
  Future<bool> renameCategory(int id, String name) => _mutate(
    () => _catalogRepository.renameCategory(id: id, name: _requiredName(name)),
  );
  Future<bool> deactivateCategory(int id) =>
      _mutate(() => _catalogRepository.deactivateCategory(id));

  Future<bool> createChannel(String name) => _mutate(
    () => _catalogRepository.createResaleChannel(name: _requiredName(name)),
  );
  Future<bool> renameChannel(int id, String name) => _mutate(
    () => _catalogRepository.renameResaleChannel(
      id: id,
      name: _requiredName(name),
    ),
  );
  Future<bool> deactivateChannel(int id) =>
      _mutate(() => _catalogRepository.deactivateResaleChannel(id));

  /// True means the write committed, even when the following read failed.
  Future<bool> _mutate(Future<Object?> Function() action) async {
    if (!canMutate) return false;
    isSaving = true;
    errorMessage = null;
    _notify();
    try {
      await action();
      _refreshRequired = true;
      if (!_disposed) await _reload();
      return true;
    } catch (error) {
      errorMessage = error.toString();
      return false;
    } finally {
      isSaving = false;
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
