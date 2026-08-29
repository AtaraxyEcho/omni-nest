import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _maximumSourceLines = 1200;

void main() {
  test('手写 Dart 源码不超过 1200 行', () async {
    final oversizedSources = <String>[];
    for (final sourceRoot in const <String>['lib', 'test']) {
      await for (final entity in Directory(sourceRoot).list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final normalizedPath = entity.path.replaceAll('\\', '/');
        if (_isGeneratedSource(normalizedPath)) {
          continue;
        }
        final lineCount = (await entity.readAsLines()).length;
        if (lineCount > _maximumSourceLines) {
          oversizedSources.add('$normalizedPath lines=$lineCount');
        }
      }
    }
    oversizedSources.sort();

    expect(
      oversizedSources,
      isEmpty,
      reason: '手写 Dart 源码超过 1200 行，请按职责拆分：\n${oversizedSources.join('\n')}',
    );
  });
}

bool _isGeneratedSource(String path) {
  return path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.startsWith('lib/app/l10n/app_localizations');
}
