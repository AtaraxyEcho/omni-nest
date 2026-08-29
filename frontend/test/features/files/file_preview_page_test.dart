import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/features/files/application/file_download_url_provider.dart';
import 'package:omninest/features/files/domain/file_node.dart';
import 'package:omninest/features/files/presentation/pages/file_preview_page.dart';

void main() {
  const file = FileNode(
    id: 'file-1',
    parentId: null,
    name: 'notes.txt',
    isFolder: false,
    nodeType: 'FILE',
    normalizedPath: '/notes.txt',
    mimeType: 'text/plain',
    sizeBytes: 64,
    updatedAt: null,
  );

  testWidgets('文本预览通过应用层状态渲染内容', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileTextPreviewProvider(
            file.id,
          ).overrideWith((ref) async => 'bounded preview'),
        ],
        child: _testApp(const FilePreviewPage(file: file)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('bounded preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('文本预览失败时显示统一错误状态', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileTextPreviewProvider(file.id).overrideWith((ref) async {
            throw const AppException(
              code: 'TEXT_PREVIEW_FAILED',
              message: '文本预览不可用',
            );
          }),
        ],
        child: _testApp(const FilePreviewPage(file: file)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('文本预览不可用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('媒体打开失败后可以重试并恢复', () async {
    var attempts = 0;
    final controller = MediaPreviewLoadController(
      opener: (_) async {
        attempts++;
        if (attempts == 1) {
          throw StateError('unsupported codec');
        }
      },
    );

    await controller.load('https://example.com/media.mp3');
    expect(controller.state, MediaPreviewLoadState.failed);

    await controller.retry();
    expect(controller.state, MediaPreviewLoadState.ready);
    expect(attempts, 2);
    controller.dispose();
  });

  test('媒体页面销毁后忽略未完成的打开结果', () async {
    final pending = Completer<void>();
    final controller = MediaPreviewLoadController(
      opener: (_) => pending.future,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    final load = controller.load('https://example.com/media.mp4');
    controller.dispose();
    pending.complete();
    await load;

    expect(notifications, 1);
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    theme: OmniNestTheme.from(AppThemePalette.dark),
    home: child,
  );
}
