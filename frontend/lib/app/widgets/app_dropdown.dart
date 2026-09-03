import 'package:flutter/material.dart';

/// 全局统一下拉选项描述。
class AppDropdownItem<T> {
  const AppDropdownItem({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;

  /// 禁用项在菜单中置灰且不可选择。
  final bool enabled;
}

/// 全局统一下拉选择：闭合态无边框填充式（聚焦主色描边 + 旋转箭头），
/// 展开菜单基于 Material 3 的 [MenuAnchor]——锚点定位、自动上下翻转、
/// 外部点击关闭与键盘导航均由框架保证；视觉上为圆角投影面板、选项
/// hover 高亮、选中项主色加粗并打勾。管理端所有下拉统一使用本控件。
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.width,
    this.suffixText,
    this.helperText,
    super.key,
  });

  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// 浮动标签；为空时不显示。
  final String? label;

  /// 固定宽度；为空时由父级约束决定。
  final double? width;
  final String? suffixText;

  /// 字段下方的辅助说明。
  final String? helperText;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  final MenuController _menu = MenuController();
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  int _indexOfValue() {
    final index = widget.items.indexWhere((item) => item.value == widget.value);
    return index < 0 ? 0 : index;
  }

  String get _currentLabel {
    final index = _indexOfValue();
    return index >= 0 && index < widget.items.length
        ? widget.items[index].label
        : '';
  }

  void _select(int index) {
    final item = widget.items[index];
    _menu.close();
    if (item.value != widget.value) {
      widget.onChanged?.call(item.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget field = Focus(
      focusNode: _focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      child: MenuAnchor(
        controller: _menu,
        useRootOverlay: true,
        alignmentOffset: const Offset(0, 6),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainerHigh),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colors.outlineVariant),
            ),
          ),
          elevation: WidgetStatePropertyAll(8),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 6),
          ),
          minimumSize: const WidgetStatePropertyAll(Size(120, 0)),
          maximumSize: const WidgetStatePropertyAll(Size(double.infinity, 320)),
        ),
        builder: (context, controller, child) {
          final isOpen = controller.isOpen;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => isOpen ? controller.close() : controller.open(),
              child: InputDecorator(
                isFocused: _focused || isOpen,
                decoration: InputDecoration(
                  labelText: widget.label,
                  helperText: widget.helperText,
                  suffixText:
                      widget.suffixText == null || widget.suffixText!.isEmpty
                          ? null
                          : widget.suffixText,
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: _fieldBorder(Colors.transparent),
                  enabledBorder: _fieldBorder(Colors.transparent),
                  focusedBorder: _fieldBorder(colors.primary),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        menuChildren: [
          for (var i = 0; i < widget.items.length; i++)
            MenuItemButton(
              onPressed: widget.items[i].enabled ? () => _select(i) : null,
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 12),
                ),
                minimumSize: const WidgetStatePropertyAll(Size.fromHeight(44)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) =>
                      states.contains(WidgetState.hovered)
                          ? colors.onSurface.withValues(alpha: 0.06)
                          : Colors.transparent,
                ),
                foregroundColor: WidgetStatePropertyAll(colors.onSurface),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.items[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            widget.items[i].value == widget.value
                                ? colors.primary
                                : colors.onSurface,
                        fontWeight:
                            widget.items[i].value == widget.value
                                ? FontWeight.w600
                                : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (widget.items[i].value == widget.value)
                    Icon(Icons.check_rounded, size: 16, color: colors.primary),
                ],
              ),
            ),
        ],
      ),
    );
    if (widget.width != null) {
      field = SizedBox(width: widget.width, child: field);
    }
    return field;
  }

  OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide:
        color == Colors.transparent
            ? BorderSide.none
            : BorderSide(color: color, width: 1.5),
  );
}
