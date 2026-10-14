import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'ledger_privacy.dart';
import 'ledger_schema.dart';

final class LedgerDatabase {
  static const fileName = 'personal_finances_ledger.db';
  static const privacyErrorMessage = '无法确认账本已排除系统自动备份';

  Database? _database;

  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('账本数据库尚未打开');
    }
    return db;
  }

  Future<void> open({
    required LedgerPrivacy privacy,
    DatabaseFactory? databaseFactoryOverride,
    String? preparedDirectoryOverride,
  }) async {
    if (_database != null) return;

    final prepared = await privacy.prepareLedgerDirectory();
    final canonicalPrepared = await _canonicalPreparedPath(prepared);
    if (!prepared.backupExcludedVerified) {
      throw const LedgerPrivacyException(privacyErrorMessage);
    }
    if (preparedDirectoryOverride != null) {
      final canonicalOverride = await _canonicalPath(preparedDirectoryOverride);
      if (canonicalOverride != canonicalPrepared) {
        throw const LedgerPrivacyException(privacyErrorMessage);
      }
    }

    final dbPath = p.join(canonicalPrepared, fileName);
    final factory = databaseFactoryOverride ?? databaseFactory;
    _database = await factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async => LedgerSchema.createV1(db),
      ),
    );
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }

  static Future<String> _canonicalPreparedPath(
    PreparedLedgerDirectory prepared,
  ) async {
    try {
      return await _canonicalPath(prepared.path);
    } on FileSystemException {
      throw const LedgerPrivacyException(privacyErrorMessage);
    }
  }

  static Future<String> _canonicalPath(String value) async {
    try {
      return await Directory(value).absolute.resolveSymbolicLinks();
    } on FileSystemException {
      throw const LedgerPrivacyException(privacyErrorMessage);
    }
  }
}
