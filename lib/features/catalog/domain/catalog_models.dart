enum BusinessScopeType { public, shop }

enum PartyKind { supplier, buyer, courier, other }

enum CashDirection { income, expense }

enum CategoryRole {
  ordinary,
  purchasePayment,
  supplierRefund,
  resaleIncome,
  resaleFee,
  courierTopUp,
  courierRefund,
  openingDebtPayment,
}

typedef CatalogId = int;

final class BusinessScope {
  const BusinessScope.public() : shopId = null;
  const BusinessScope.shop(this.shopId);

  final int? shopId;

  BusinessScopeType get type =>
      shopId == null ? BusinessScopeType.public : BusinessScopeType.shop;
}

final class Shop {
  const Shop({required this.id, required this.name, required this.isActive});

  final int id;
  final String name;
  final bool isActive;
}

final class AccountLabel {
  const AccountLabel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;
}

final class Party {
  const Party({
    required this.id,
    required this.name,
    required this.kind,
    required this.isActive,
  });

  final int id;
  final String name;
  final PartyKind kind;
  final bool isActive;
}

final class Category {
  const Category({
    required this.id,
    required this.name,
    required this.direction,
    required this.role,
    required this.isSystem,
    required this.isActive,
  });

  final int id;
  final String name;
  final CashDirection direction;
  final CategoryRole role;
  final bool isSystem;
  final bool isActive;
}

final class ResaleChannel {
  const ResaleChannel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;
}
