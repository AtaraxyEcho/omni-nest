# -*- coding: utf-8 -*-
"""编辑器工具栏饱和度 + 预览矩阵对齐后端语义。"""
import io


def load(p):
    return io.open(p, encoding='utf-8').read()


def save(p, s):
    io.open(p, 'w', encoding='utf-8', newline='').write(s)


def rep(s, old, new, what):
    assert old in s, 'NOT FOUND [' + what + ']: ' + old[:90]
    return s.replace(old, new, 1)

# ── 1) 工具栏：饱和度滑杆 ──
p = 'lib/features/photos/presentation/widgets/photo_editor_toolbar.dart'
s = load(p)

s = rep(s, """  const PhotoEditorToolbar({
    required this.selectedTool,
    required this.onToolSelected,
    required this.onRotate,
    required this.onCrop,
    required this.brightness,
    required this.contrast,
    required this.selectedFilter,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onFilterSelected,
    super.key,
  });

  final EditTool? selectedTool;
  final ValueChanged<EditTool?> onToolSelected;
  final VoidCallback onRotate;
  final VoidCallback onCrop;
  final double brightness;
  final double contrast;
  final FilterPreset selectedFilter;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<FilterPreset> onFilterSelected;""",
"""  const PhotoEditorToolbar({
    required this.selectedTool,
    required this.onToolSelected,
    required this.onRotate,
    required this.onCrop,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.selectedFilter,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onSaturationChanged,
    required this.onFilterSelected,
    super.key,
  });

  final EditTool? selectedTool;
  final ValueChanged<EditTool?> onToolSelected;
  final VoidCallback onRotate;
  final VoidCallback onCrop;
  final double brightness;
  final double contrast;
  final double saturation;
  final FilterPreset selectedFilter;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<FilterPreset> onFilterSelected;""", 'toolbar params')

s = rep(s, """          if (selectedTool == EditTool.filter)
            _FilterChips(
              selected: selectedFilter,
              onSelected: onFilterSelected,
            ),""",
"""          if (selectedTool == EditTool.saturation)
            _SliderRow(
              label: AppLocalizations.of(context).photosSaturation,
              value: saturation,
              min: -1,
              max: 1,
              onChanged: onSaturationChanged,
            ),
          if (selectedTool == EditTool.filter)
            _FilterChips(
              selected: selectedFilter,
              onSelected: onFilterSelected,
            ),""", 'saturation slider')
save(p, s)
print('toolbar ok')

# ── 2) 编辑页：接线 + 预览矩阵对齐后端语义 ──
p = 'lib/features/photos/presentation/pages/photo_editor_page.dart'
s = load(p)

s = rep(s, """              onBrightnessChanged: (v) => setState(() => _brightness = v),
              onContrastChanged: (v) => setState(() => _contrast = v),""",
"""              onBrightnessChanged: (v) => setState(() => _brightness = v),
              onContrastChanged: (v) => setState(() => _contrast = v),
              onSaturationChanged: (v) => setState(() => _saturation = v),""", 'body wiring')

s = rep(s, """    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onFilterSelected,
    required this.onSave,
    required this.onShowVersions,
  });

  final PhotoItem photo;
  final EditTool? selectedTool;
  final double brightness;
  final double contrast;
  final FilterPreset filter;""",
"""    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onSaturationChanged,
    required this.onFilterSelected,
    required this.onSave,
    required this.onShowVersions,
  });

  final PhotoItem photo;
  final EditTool? selectedTool;
  final double brightness;
  final double contrast;
  final double saturation;
  final FilterPreset filter;""", 'body params')

s = rep(s, """  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<FilterPreset> onFilterSelected;
  final VoidCallback onSave;
  final VoidCallback onShowVersions;""",
"""  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<FilterPreset> onFilterSelected;
  final VoidCallback onSave;
  final VoidCallback onShowVersions;""", 'body callback fields')

# _EditorBody 调用点补参数
s = rep(s, """            onBrightnessChanged:
                (v) => setState(() => _brightness = v),
            onContrastChanged:
                (v) => setState(() => _contrast = v),""",
"""            onBrightnessChanged:
                (v) => setState(() => _brightness = v),
            onContrastChanged:
                (v) => setState(() => _contrast = v),
            onSaturationChanged:
                (v) => setState(() => _saturation = v),""", 'page call site')

# 预览矩阵：亮度为乘法、对比度带偏移，与后端保存语义一致；叠加饱和度
s = rep(s, """  List<double> _buildColorMatrix() {
    // 亮度调整
    final b = brightness;
    // 对比度调整
    final c = contrast;
    // 基础矩阵（亮度 + 对比度）
    final matrix = <double>[
      c,
      0.0,
      0.0,
      0.0,
      b * 255,
      0.0,
      c,
      0.0,
      0.0,
      b * 255,
      0.0,
      0.0,
      c,
      0.0,
      b * 255,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // 滤镜叠加
    switch (filter) {
      case FilterPreset.grayscale:
        return _applyGrayscale(matrix);
      case FilterPreset.sepia:
        return _applySepia(matrix);
      case FilterPreset.original:
      case FilterPreset.blur:
      case FilterPreset.sharpen:
        // blur/sharpen 需要 ConvolveOp，前端仅做颜色矩阵
        return matrix;
    }
  }""",
"""  List<double> _buildColorMatrix() {
    // 与后端保存语义对齐：亮度为乘法系数 (1+b)，对比度为 (v-128)*c+128。
    final brightnessScale = 1 + brightness;
    final c = contrast;
    final scale = c * brightnessScale;
    final offset = 128 * (1 - c);
    final matrix = <double>[
      scale,
      0.0,
      0.0,
      0.0,
      offset,
      0.0,
      scale,
      0.0,
      0.0,
      offset,
      0.0,
      0.0,
      scale,
      0.0,
      offset,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // 滤镜与饱和度叠加
    switch (filter) {
      case FilterPreset.grayscale:
        return _applyGrayscale(_applySaturation(matrix));
      case FilterPreset.sepia:
        return _applySepia(_applySaturation(matrix));
      case FilterPreset.original:
        return _applySaturation(matrix);
      case FilterPreset.blur:
      case FilterPreset.sharpen:
        // blur/sharpen 需要 ConvolveOp，前端仅做颜色矩阵
        return _applySaturation(matrix);
    }
  }

  /// 饱和度矩阵：out = gray + f * (in - gray)，f = 1 + saturation。
  List<double> _applySaturation(List<double> m) {
    final f = 1 + saturation;
    const lr = 0.299;
    const lg = 0.587;
    const lb = 0.114;
    // 灰度对输入像素的系数行
    final grayR = lr * m[0] + lg * m[5] + lb * m[10];
    final grayG = lr * m[1] + lg * m[6] + lb * m[11];
    final grayB = lr * m[2] + lg * m[7] + lb * m[12];
    return <double>[
      f * m[0] + (1 - f) * grayR,
      f * m[1] + (1 - f) * grayG,
      f * m[2] + (1 - f) * grayB,
      0.0,
      m[4],
      f * m[5] + (1 - f) * grayR,
      f * m[6] + (1 - f) * grayG,
      f * m[7] + (1 - f) * grayB,
      0.0,
      m[9],
      f * m[10] + (1 - f) * grayR,
      f * m[11] + (1 - f) * grayG,
      f * m[12] + (1 - f) * grayB,
      0.0,
      m[14],
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }""", 'preview matrix')

save(p, s)
print('editor page ok')

# ── 3) EditTool 枚举：saturation ──
p = 'lib/features/photos/presentation/widgets/photo_editor_top_bar.dart'
s = load(p)
import re
m = re.search(r'enum EditTool \{[^}]*\}', s)
if m:
    assert 'saturation' not in m.group(0)
    s = s.replace(m.group(0), m.group(0).replace('}', ', saturation }'), 1)
    io.open(p, 'w', encoding='utf-8', newline='').write(s)
    print('enum ok')
else:
    print('enum not in top bar — locate separately')
