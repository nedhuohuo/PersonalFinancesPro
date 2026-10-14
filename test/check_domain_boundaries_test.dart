import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_domain_boundaries.dart' as boundaries;

void main() {
  test(
    'domain boundary check validates decoded direct and conditional directives',
    () async {
      final temp = await Directory.systemTemp.createTemp('domain-boundary-');
      addTearDown(() async => temp.delete(recursive: true));

      Future<void> write(String relativePath, String content) async {
        final file = File('${temp.path}/$relativePath');
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
      }

      await write('allowed/lib/core/domain/money.dart', 'const money = 1;');
      await write('allowed/lib/core/domain/extra.dart', 'const extra = 1;');
      await write('allowed/lib/core/domain/allowed.dart', r'''
import r'dart:math';
import 'mone\u0079.dart'
    if (dart.library.io) /* choose IO */ r'extra.dart';
import 'money.dart'
    if (dart.library.io == 'package:flutter/cupertino.dart') 'extra.dart';
export """package:personal_finances_pro/core/domain/money.dart"""
    if (dart.library.io)
    'package:personal_finances_pro/core/domain/extra.dart';
''');
      await write('raw_import/lib/core/domain/bad.dart', r'''
import r'package:flutter/cupertino.dart';
''');
      await write('escaped_export/lib/core/domain/bad.dart', r'''
export 'package:flutter/cupertino.d\u0061rt';
''');
      await write('triple_import/lib/core/domain/bad.dart', r'''
import """package:flutter/cupertino.dart""";
''');
      await write('conditional_import/lib/core/domain/bad.dart', r'''
import 'money.dart'
    if (dart.library.ui)
    'package:flutter/cupertino.dart';
''');
      await write('conditional_export/lib/core/domain/bad.dart', r'''
export 'money.dart' // primary stays in domain
    if (dart.library.ui)
    r'package:flutter/cupertino.dart';
''');
      await write('non_static/lib/core/domain/bad.dart', r'''
import 'package:$name/flutter.dart';
''');
      await write('malformed/lib/core/domain/bad.dart', r'''
import ;
''');

      expect(
        boundaries.checkDomainBoundaries(['${temp.path}/allowed/lib']),
        isEmpty,
      );

      for (final root in [
        'raw_import/lib',
        'escaped_export/lib',
        'triple_import/lib',
        'conditional_import/lib',
        'conditional_export/lib',
      ]) {
        final errors = boundaries.checkDomainBoundaries(['${temp.path}/$root']);
        expect(errors, isNotEmpty, reason: '$root should be rejected');
        expect(errors.single, contains('package:flutter/cupertino.dart'));
      }

      for (final root in ['non_static/lib', 'malformed/lib']) {
        final errors = boundaries.checkDomainBoundaries(['${temp.path}/$root']);
        expect(errors, isNotEmpty, reason: '$root should be rejected');
      }
    },
  );
}
