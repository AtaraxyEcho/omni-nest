import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations_en.dart';
import 'package:omninest/app/l10n/app_localizations_zh.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_editor_configs.dart';

void main() {
  test('编辑器配置输出中文文案', () {
    final configs = buildPhotoEditorConfigs(AppLocalizationsZh());
    expect(configs.i18n.cancel, '取消');
    expect(configs.i18n.done, '完成');
    expect(configs.i18n.paintEditor.bottomNavigationBarText, '绘画');
    expect(configs.i18n.textEditor.bottomNavigationBarText, '文字');
    expect(configs.i18n.cropRotateEditor.bottomNavigationBarText, '裁剪旋转');
    expect(configs.i18n.tuneEditor.brightness, '亮度');
    expect(configs.i18n.filterEditor.bottomNavigationBarText, '滤镜');
    expect(configs.cropRotateEditor.aspectRatios.first.text, '自由');
    expect(configs.cropRotateEditor.aspectRatios[1].text, '原始');
  });

  test('编辑器配置输出英文文案', () {
    final configs = buildPhotoEditorConfigs(AppLocalizationsEn());
    expect(configs.i18n.cancel, 'Cancel');
    expect(configs.i18n.paintEditor.bottomNavigationBarText, 'Paint');
    expect(configs.cropRotateEditor.aspectRatios.first.text, 'Free');
  });
}
