import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

const packagePrefix = 'package:personal_finances_pro/';

void main(List<String> args) {
  final errors = checkDomainBoundaries(args.isEmpty ? ['lib'] : args);

  if (errors.isNotEmpty) {
    stderr.writeln('Domain boundary violations:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
  }
}

List<String> checkDomainBoundaries(List<String> roots) {
  final errors = <String>[];

  for (final file in _domainFiles(roots)) {
    final source = file.readAsStringSync();
    final parseResult = parseString(
      content: source,
      path: file.path,
      throwIfDiagnostics: false,
    );
    for (final error in parseResult.errors) {
      errors.add('${file.path}: parse error: ${error.message}');
    }

    for (final directive
        in parseResult.unit.directives.whereType<NamespaceDirective>()) {
      final keyword = directive is ImportDirective ? 'import' : 'export';
      for (final uri in _directiveUris(directive)) {
        if (uri == null) {
          errors.add('${file.path}: $keyword URI must be a static string');
          continue;
        }
        final error = _checkDirective(file, uri);
        if (error != null) {
          errors.add('${file.path}: $keyword $uri: $error');
        }
      }
    }
  }

  return errors;
}

Iterable<File> _domainFiles(List<String> roots) sync* {
  for (final root in roots) {
    final type = FileSystemEntity.typeSync(root);
    if (type == FileSystemEntityType.file && root.endsWith('.dart')) {
      final file = File(root);
      if (_isDomainPath(file.path)) yield file;
      continue;
    }
    if (type != FileSystemEntityType.directory) continue;

    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          _isDomainPath(entity.path)) {
        yield entity;
      }
    }
  }
}

Iterable<String?> _directiveUris(NamespaceDirective directive) sync* {
  yield directive.uri.stringValue;
  for (final configuration in directive.configurations) {
    yield configuration.uri.stringValue;
  }
}

String? _checkDirective(File file, String uri) {
  if (uri.startsWith('dart:')) return null;

  if (uri.startsWith('package:')) {
    if (!uri.startsWith(packagePrefix)) {
      return 'only dart: and package:personal_finances_pro domain imports are allowed';
    }
    final target =
        Uri(
          path: 'lib/${uri.substring(packagePrefix.length)}',
        ).normalizePath().path;
    return _isDomainPath(target)
        ? null
        : 'package import must target a domain folder';
  }

  if (uri.contains(':')) {
    return 'unsupported URI scheme';
  }

  final targetPath =
      file.absolute.uri.resolve(uri).normalizePath().toFilePath();
  return _isDomainPath(targetPath)
      ? null
      : 'relative import must stay inside a domain folder';
}

bool _isDomainPath(String path) {
  return path.split(RegExp(r'[/\\]+')).contains('domain');
}
