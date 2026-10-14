import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

final class PreparedLedgerDirectory {
  const PreparedLedgerDirectory({
    required this.path,
    required this.backupExcludedVerified,
  });

  final String path;
  final bool backupExcludedVerified;
}

abstract interface class LedgerPrivacy {
  Future<PreparedLedgerDirectory> prepareLedgerDirectory();
}

final class LedgerPrivacyException implements Exception {
  const LedgerPrivacyException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class MethodChannelLedgerPrivacy implements LedgerPrivacy {
  const MethodChannelLedgerPrivacy();

  static const channel = MethodChannel(
    'dev.nedhuohuo.personalfinancespro/ledger_privacy',
  );

  @override
  Future<PreparedLedgerDirectory> prepareLedgerDirectory() async {
    if (Platform.isAndroid) {
      final path = await getDatabasesPath();
      final directory = await Directory(path).create(recursive: true);
      return PreparedLedgerDirectory(
        path: await directory.absolute.resolveSymbolicLinks(),
        backupExcludedVerified: true,
      );
    }

    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'prepareLedgerDirectory',
      );
      final path = result?['path'];
      final verified = result?['backupExcludedVerified'];
      if (path is! String || verified != true) {
        throw const LedgerPrivacyException('无法确认账本已排除系统自动备份');
      }
      return PreparedLedgerDirectory(path: path, backupExcludedVerified: true);
    } on PlatformException {
      throw const LedgerPrivacyException('无法确认账本已排除系统自动备份');
    }
  }
}
