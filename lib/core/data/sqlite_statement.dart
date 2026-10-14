import 'package:personal_finances_pro/features/catalog/domain/catalog_models.dart';
import 'package:personal_finances_pro/features/ledger/domain/ledger_models.dart';

bool sqliteBool(Object? value) => value == 1;
int sqliteBoolValue(bool value) => value ? 1 : 0;

String cashDirectionValue(CashDirection value) => value.name;
String categoryRoleValue(CategoryRole value) => value.name;
String partyKindValue(PartyKind value) => value.name;
String entrySourceValue(EntrySource value) => value.name;
String businessOriginValue(BusinessOrigin value) => value.name;
String linkedBillTypeValue(LinkedBillType value) => value.name;
String businessScopeTypeValue(BusinessScopeType value) => value.name;

CashDirection cashDirectionFromSql(Object? value) =>
    CashDirection.values.byName(value! as String);
CategoryRole categoryRoleFromSql(Object? value) =>
    CategoryRole.values.byName(value! as String);
PartyKind partyKindFromSql(Object? value) =>
    PartyKind.values.byName(value! as String);
EntrySource entrySourceFromSql(Object? value) =>
    EntrySource.values.byName(value! as String);
BusinessOrigin businessOriginFromSql(Object? value) =>
    BusinessOrigin.values.byName(value! as String);
LinkedBillType? linkedBillTypeFromSql(Object? value) =>
    value == null ? null : LinkedBillType.values.byName(value as String);
BusinessScope businessScopeFromSql(Map<String, Object?> row) =>
    row['scope_type'] == 'shop'
        ? BusinessScope.shop(row['shop_id']! as int)
        : const BusinessScope.public();

String utcNowIso() => DateTime.now().toUtc().toIso8601String();
