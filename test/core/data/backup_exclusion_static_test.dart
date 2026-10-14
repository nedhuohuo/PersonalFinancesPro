import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android manifest and backup rules exclude ledger database locations',
    () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );

      final backupRules =
          File(
            'android/app/src/main/res/xml/backup_rules.xml',
          ).readAsStringSync();
      expect(backupRules, contains('<exclude domain="database" path="." />'));
      expect(backupRules, contains('<exclude domain="file" path="ledger" />'));

      final extractionRules =
          File(
            'android/app/src/main/res/xml/data_extraction_rules.xml',
          ).readAsStringSync();
      expect(extractionRules, contains('<cloud-backup>'));
      expect(extractionRules, contains('<device-transfer>'));
      expect(
        RegExp(
          r'<exclude domain="database" path="\." />',
        ).allMatches(extractionRules),
        hasLength(2),
      );
      expect(
        RegExp(
          r'<exclude domain="file" path="ledger" />',
        ).allMatches(extractionRules),
        hasLength(2),
      );
    },
  );

  test(
    'iOS app delegate registers ledger privacy channel with readback verification',
    () {
      final appDelegate =
          File('ios/Runner/AppDelegate.swift').readAsStringSync();
      expect(
        appDelegate,
        contains('dev.nedhuohuo.personalfinancespro/ledger_privacy'),
      );
      expect(appDelegate, contains('isExcludedFromBackupKey'));
      expect(appDelegate, contains('backupExcludedVerified'));
      expect(appDelegate, contains('applicationSupportDirectory'));
      expect(appDelegate, contains('ledger'));
    },
  );

  test('iOS plugin wiring uses portable Flutter/CocoaPods source config', () {
    final podfile = File('ios/Podfile').readAsStringSync();
    expect(podfile, contains('Generated.xcconfig'));
    expect(podfile, contains('flutter_ios_podfile_setup'));
    expect(podfile, contains('flutter_install_all_ios_pods'));
    expect(podfile, isNot(contains('/Users/')));

    final debug = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
    final release = File('ios/Flutter/Release.xcconfig').readAsStringSync();
    expect(
      debug,
      contains(
        '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"',
      ),
    );
    expect(
      release,
      contains(
        '#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"',
      ),
    );
  });
}
