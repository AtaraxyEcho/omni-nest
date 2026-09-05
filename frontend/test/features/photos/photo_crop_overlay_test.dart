import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_crop_overlay.dart';

void main() {
  testWidgets('裁剪框按 contain 绘制比例线性映射回原图坐标', (tester) async {
    Rect? confirmed;

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniNestTheme.from(AppThemePalette.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: PhotoCropOverlay(
                // 原图 1000x500（2:1），在 400x400 的区域按 contain 绘制为
                // 400x200，垂直居中，上下各留 100px。
                imageWidth: 1000,
                imageHeight: 500,
                preview: const ColoredBox(color: Colors.blue),
                onConfirmed: (rect) => confirmed = rect,
                onCancelled: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 在绘制区域内拖出 (40, 40) 到 (240, 140) 的矩形（绘制区局部坐标）。
    // dragFrom 使用全局坐标，需叠加组件原点偏移。
    final origin = tester.getTopLeft(find.byType(PhotoCropOverlay));
    await tester.dragFrom(
      origin + const Offset(40, 140),
      const Offset(200, 100),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    // 换算比例 1000/400 = 2.5。绘制区顶部位于顶栏 48px + 居中留边 76px =
    // 124px，故拖拽局部坐标 (40,16)-(240,116) → 原图 (100,40)-(600,290)。
    expect(confirmed, Rect.fromLTRB(100, 40, 600, 290));
  });
}
