import 'package:sqflite/sqflite.dart';

final class LedgerSchema {
  const LedgerSchema._();

  static Future<void> createV1(Database db) async {
    for (final statement in _v1Statements) {
      await db.execute(statement);
    }
  }
}

const _v1Statements = [
  """
CREATE TABLE shops (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL)
""",
  """
CREATE TABLE account_labels (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL)
""",
  """
CREATE TABLE parties (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, kind TEXT NOT NULL CHECK (kind IN ('supplier', 'buyer', 'courier', 'other')), is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, UNIQUE (name, kind))
""",
  """
CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')), role TEXT NOT NULL CHECK (role IN ('ordinary', 'purchasePayment', 'supplierRefund', 'resaleIncome', 'resaleFee', 'courierTopUp', 'courierRefund', 'openingDebtPayment')), is_system INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0, 1)), is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, UNIQUE (name, direction))
""",
  """
CREATE TABLE resale_channels (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL)
""",
  """
CREATE TABLE cash_bills (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  business_date TEXT NOT NULL,
  direction TEXT NOT NULL CHECK (direction IN ('income', 'expense')),
  amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000),
  scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')),
  shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  account_id INTEGER NOT NULL REFERENCES account_labels(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  party_id INTEGER REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
  note TEXT NOT NULL DEFAULT '',
  entry_source TEXT NOT NULL CHECK (entry_source IN ('manual', 'ai')),
  business_origin TEXT NOT NULL CHECK (business_origin IN ('ordinary', 'purchasePayment', 'supplierRefund', 'resaleIncome', 'resaleFee', 'courierTopUp', 'courierRefund', 'openingDebtPayment')),
  linked_type TEXT CHECK (linked_type IN ('purchasePayment', 'supplierRefund', 'openingDebtPayment', 'problemResaleIncome', 'problemResaleFee', 'courierTopUp', 'courierRefund')),
  linked_id INTEGER,
  is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  voided_at_utc TEXT,
  CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)),
  CHECK ((business_origin = 'ordinary' AND linked_type IS NULL AND linked_id IS NULL) OR (business_origin <> 'ordinary' AND linked_type IS NOT NULL AND linked_id IS NOT NULL))
)
""",
  'CREATE INDEX cash_bills_filter_idx ON cash_bills(business_date, scope_type, shop_id, category_id, party_id, is_void)',
  'CREATE INDEX cash_bills_link_idx ON cash_bills(linked_type, linked_id)',
  """
CREATE TABLE purchases (id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT, business_date TEXT NOT NULL, scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, item_total_cents INTEGER NOT NULL CHECK (item_total_cents >= 0 AND item_total_cents <= 9000000000000000), supplier_freight_cents INTEGER NOT NULL CHECK (supplier_freight_cents >= 0 AND supplier_freight_cents <= 9000000000000000), original_total_cents INTEGER NOT NULL CHECK (original_total_cents > 0 AND original_total_cents <= 9000000000000000), effective_total_cents INTEGER NOT NULL CHECK (effective_total_cents >= 0 AND effective_total_cents <= 9000000000000000), note TEXT NOT NULL DEFAULT '', is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, voided_at_utc TEXT, CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)))
""",
  'CREATE TABLE purchase_items (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT, description TEXT NOT NULL, quantity INTEGER NOT NULL CHECK (quantity > 0), unit_price_cents INTEGER NOT NULL CHECK (unit_price_cents > 0 AND unit_price_cents <= 9000000000000000), line_total_cents INTEGER NOT NULL CHECK (line_total_cents > 0 AND line_total_cents <= 9000000000000000))',
  'CREATE TABLE purchase_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL)',
  """
CREATE TABLE purchase_adjustments (id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL REFERENCES purchases(id) ON UPDATE RESTRICT ON DELETE RESTRICT, kind TEXT NOT NULL CHECK (kind IN ('unpaidWaiver', 'paidRefund')), amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, reason TEXT NOT NULL, is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK ((kind = 'paidRefund' AND cash_bill_id IS NOT NULL) OR (kind = 'unpaidWaiver' AND cash_bill_id IS NULL)))
""",
  """
CREATE TABLE supplier_opening_debts (id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT, business_date TEXT NOT NULL, scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), paid_cents INTEGER NOT NULL DEFAULT 0 CHECK (paid_cents >= 0 AND paid_cents <= 9000000000000000), note TEXT NOT NULL DEFAULT '', is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK (paid_cents <= amount_cents), CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)))
""",
  'CREATE TABLE supplier_opening_debt_payments (id INTEGER PRIMARY KEY AUTOINCREMENT, opening_debt_id INTEGER NOT NULL REFERENCES supplier_opening_debts(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL)',
  """
CREATE TABLE problem_resales (id INTEGER PRIMARY KEY AUTOINCREMENT, business_date TEXT NOT NULL, scope_type TEXT NOT NULL CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, description TEXT NOT NULL, quantity INTEGER NOT NULL CHECK (quantity > 0), income_cents INTEGER NOT NULL CHECK (income_cents > 0 AND income_cents <= 9000000000000000), income_cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, buyer_id INTEGER NOT NULL REFERENCES parties(id) ON UPDATE RESTRICT ON DELETE RESTRICT, channel_id INTEGER NOT NULL REFERENCES resale_channels(id) ON UPDATE RESTRICT ON DELETE RESTRICT, issue_note TEXT NOT NULL, is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL)))
""",
  'CREATE TABLE problem_resale_fees (id INTEGER PRIMARY KEY AUTOINCREMENT, resale_id INTEGER NOT NULL REFERENCES problem_resales(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER NOT NULL UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, category_id INTEGER NOT NULL REFERENCES categories(id) ON UPDATE RESTRICT ON DELETE RESTRICT, account_id INTEGER NOT NULL REFERENCES account_labels(id) ON UPDATE RESTRICT ON DELETE RESTRICT, amount_cents INTEGER NOT NULL CHECK (amount_cents > 0 AND amount_cents <= 9000000000000000), created_at_utc TEXT NOT NULL)',
  'CREATE TABLE courier_accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL)',
  """
CREATE TABLE courier_events (id INTEGER PRIMARY KEY AUTOINCREMENT, courier_account_id INTEGER NOT NULL REFERENCES courier_accounts(id) ON UPDATE RESTRICT ON DELETE RESTRICT, business_date TEXT NOT NULL, event_type TEXT NOT NULL CHECK (event_type IN ('opening', 'topUp', 'consume', 'refund')), amount_cents INTEGER NOT NULL CHECK (amount_cents >= 0 AND amount_cents <= 9000000000000000), scope_type TEXT CHECK (scope_type IN ('public', 'shop')), shop_id INTEGER REFERENCES shops(id) ON UPDATE RESTRICT ON DELETE RESTRICT, cash_bill_id INTEGER UNIQUE REFERENCES cash_bills(id) ON UPDATE RESTRICT ON DELETE RESTRICT, balance_after_cents INTEGER NOT NULL CHECK (balance_after_cents >= 0 AND balance_after_cents <= 9000000000000000), note TEXT NOT NULL DEFAULT '', is_void INTEGER NOT NULL DEFAULT 0 CHECK (is_void IN (0, 1)), voided_at_utc TEXT, created_at_utc TEXT NOT NULL, updated_at_utc TEXT NOT NULL, CHECK ((event_type = 'opening' AND scope_type IS NULL AND shop_id IS NULL AND cash_bill_id IS NULL) OR (event_type = 'consume' AND scope_type IS NOT NULL AND cash_bill_id IS NULL) OR (event_type IN ('topUp', 'refund') AND scope_type IS NOT NULL)), CHECK ((scope_type = 'public' AND shop_id IS NULL) OR (scope_type = 'shop' AND shop_id IS NOT NULL) OR (scope_type IS NULL AND shop_id IS NULL)))
""",
  'CREATE TABLE audit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, entity_type TEXT NOT NULL, entity_id INTEGER NOT NULL, action TEXT NOT NULL, reason TEXT NOT NULL DEFAULT \'\', snapshot_json TEXT NOT NULL, created_at_utc TEXT NOT NULL)',
  'PRAGMA user_version = 1',
];
