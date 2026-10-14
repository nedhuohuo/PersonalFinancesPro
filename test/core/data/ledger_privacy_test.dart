import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finances_pro/core/data/ledger_database.dart';
import 'package:personal_finances_pro/core/data/ledger_privacy.dart';

final class FakePrivacy implements LedgerPrivacy {
  FakePrivacy(this.directory);
  final PreparedLedgerDirectory directory;

  @override
  Future<PreparedLedgerDirectory> prepareLedgerDirectory() async => directory;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('open rejects unverified directory before creating a db file', () async {
    final dir = await Directory.systemTemp.createTemp('ledger-privacy-');
    addTearDown(() => dir.delete(recursive: true));
    final db = LedgerDatabase();

    await expectLater(
      db.open(
        privacy: FakePrivacy(
          PreparedLedgerDirectory(
            path: dir.path,
            backupExcludedVerified: false,
          ),
        ),
        preparedDirectoryOverride: dir.path,
      ),
      throwsA(isA<LedgerPrivacyException>()),
    );

    expect(
      File('${dir.path}/personal_finances_ledger.db').existsSync(),
      isFalse,
    );
  });

  test(
    'open rejects mismatched prepared path before creating a db file',
    () async {
      final prepared = await Directory.systemTemp.createTemp(
        'ledger-prepared-',
      );
      final other = await Directory.systemTemp.createTemp('ledger-other-');
      addTearDown(() async {
        await prepared.delete(recursive: true);
        await other.delete(recursive: true);
      });
      final db = LedgerDatabase();

      await expectLater(
        db.open(
          privacy: FakePrivacy(
            PreparedLedgerDirectory(
              path: prepared.path,
              backupExcludedVerified: true,
            ),
          ),
          preparedDirectoryOverride: other.path,
        ),
        throwsA(isA<LedgerPrivacyException>()),
      );

      expect(
        File('${other.path}/personal_finances_ledger.db').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'iOS privacy channel accepts only verified directory responses',
    () async {
      final dir = await Directory.systemTemp.createTemp('ledger-channel-');
      addTearDown(() => dir.delete(recursive: true));
      const channel = MethodChannelLedgerPrivacy.channel;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'prepareLedgerDirectory');
            return {'path': dir.path, 'backupExcludedVerified': true};
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final prepared =
          await const MethodChannelLedgerPrivacy().prepareLedgerDirectory();

      expect(prepared.path, dir.path);
      expect(prepared.backupExcludedVerified, isTrue);
    },
  );

  test('iOS privacy channel rejects unverified responses', () async {
    const channel = MethodChannelLedgerPrivacy.channel;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return {'path': '/tmp/ledger', 'backupExcludedVerified': false};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await expectLater(
      const MethodChannelLedgerPrivacy().prepareLedgerDirectory(),
      throwsA(isA<LedgerPrivacyException>()),
    );
  });

  test(
    'iOS privacy channel converts native errors to privacy errors',
    () async {
      const channel = MethodChannelLedgerPrivacy.channel;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'ledger_privacy_failed');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      await expectLater(
        const MethodChannelLedgerPrivacy().prepareLedgerDirectory(),
        throwsA(isA<LedgerPrivacyException>()),
      );
    },
  );
}
