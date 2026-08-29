import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/features/files/domain/file_manager_models.dart';
import 'package:omninest/features/files/presentation/widgets/external_storage_account_dialog.dart';

void main() {
  testWidgets('外部存储表单提交结构化 S3 凭据', (tester) async {
    ({String provider, String displayName, String credentialsJson})? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniNestTheme.from(AppThemePalette.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => FilledButton(
                  onPressed: () async {
                    result = await showDialog(
                      context: context,
                      builder: (_) => const ExternalStorageAccountDialog(),
                    );
                  },
                  child: const Text('打开'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(0), '家庭对象存储');
    await tester.enterText(fields.at(1), 'access-key');
    await tester.enterText(fields.at(2), 'secret-key');
    await tester.enterText(fields.at(3), 'https://storage.example.com');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, '添加外部存储'));
    await tester.pumpAndSettle();

    expect(result?.provider, 'S3');
    expect(result?.displayName, '家庭对象存储');
    expect(jsonDecode(result!.credentialsJson), {
      'provider': 'Minio',
      'access_key_id': 'access-key',
      'secret_access_key': 'secret-key',
      'endpoint': 'https://storage.example.com',
    });
  });

  testWidgets('编辑外部存储时反填连接元数据并保留已有密钥', (tester) async {
    ({String provider, String displayName, String credentialsJson})? result;
    const account = ExternalStorageAccount(
      id: 'storage-id',
      provider: 'S3',
      displayName: '家庭对象存储',
      connectionMetadata: {
        'provider': 'Minio',
        'access_key_id': 'saved-access-key',
        'endpoint': 'https://storage.example.com',
        'region': 'cn-east-1',
      },
      credentialsConfigured: true,
      status: 'ACTIVE',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniNestTheme.from(AppThemePalette.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Builder(
            builder:
                (context) => FilledButton(
                  onPressed: () async {
                    result = await showDialog(
                      context: context,
                      builder:
                          (_) => const ExternalStorageAccountDialog(
                            account: account,
                          ),
                    );
                  },
                  child: const Text('编辑'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(5));
    expect(find.text('家庭对象存储'), findsOneWidget);
    expect(find.text('saved-access-key'), findsOneWidget);
    expect(find.text('https://storage.example.com'), findsOneWidget);
    expect(find.text('cn-east-1'), findsOneWidget);
    expect(find.text('留空以保留已保存的值'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();

    final credentials = jsonDecode(result!.credentialsJson) as Map;
    expect(credentials['access_key_id'], 'saved-access-key');
    expect(credentials['endpoint'], 'https://storage.example.com');
    expect(credentials['region'], 'cn-east-1');
    expect(credentials, isNot(contains('secret_access_key')));
  });
}
