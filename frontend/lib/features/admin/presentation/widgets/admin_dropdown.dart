import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 管理端统一下拉选项描述。
/// 管理端统一下拉选项描述。
class AdminDropdownItem<T> {
  const AdminDropdownItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// 管理端统一下拉选择：描边圆角、密集高度、选中项与菜单项省略，
/// 避免长文本把固定宽字段撑爆。管理端所有下拉统一使用本控件。
/// 管理端统一下拉选择：闭合态为无边框填充式（聚焦主色描边 + 旋转箭头），
/// 展开菜单为圆角面板（面板同源底色、选项 hover 高亮、选中项打勾）。
/// 管理端所有下拉统一使用本控件，避免长文本把固定宽字段撑爆。
/// 管理端统一下拉选择：闭合态无边框填充式（聚焦主色描边 + 旋转箭头），
/// 展开菜单为自绘浮层面板（圆角、投影、选项 hover/键盘高亮、选中打勾、
/// 自动上下翻转），支持键盘上下选择与 Esc 关闭。管理端所有下拉统一使用
/// 本控件，避免长文本把固定宽字段撑爆。
class AdminDropdown<T> extends StatefulWidget {
  const AdminDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.width,
    this.suffixText,
    super.key,
  });

  final T value;
  final List<AdminDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;

  /// 浮动标签；为空时不显示。
  final String? label;

  /// 固定宽度；为空时由父级约束决定。
  final double? width;
  final String? suffixText;

  @override
  State<AdminDropdown<T>> createState() => _AdminDropdownState<T>();
}

class _AdminDropdownState<T> extends State<AdminDropdown<T>>
    with SingleTickerProviderStateMixin {
  static const double _optionHeight = 44;
  static const double _menuMaxHeight = 320;

  final LayerLink _layerLink = LayerLink();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _menuController = ScrollController();
  final Object _groupId = Object();
  late final AnimationController _anim;

  OverlayEntry? _entry;
  bool _open = false;
  bool _focused = false;
  bool _menuUp = false;
  double _menuWidth = 160;
  late int _highlighted = _indexOfValue();

  bool get _enabled => widget.onChanged != null;

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

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void didUpdateWidget(AdminDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _highlighted = _indexOfValue();
    }
  }

  @override
  void dispose() {
    _removeEntry();
    _focusNode.dispose();
    _menuController.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _openMenu() {
    if (_open || !_enabled) return;
    final box = context.findRenderObject() as RenderBox;
    _menuWidth = box.size.width;
    final fieldTop = box.localToGlobal(Offset.zero).dy;
    final menuHeight = math.min(
      widget.items.length * _optionHeight + 12,
      _menuMaxHeight,
    );
    final screenH = MediaQuery.sizeOf(context).height;
    _menuUp =
        fieldTop + menuHeight + 8 > screenH && fieldTop - menuHeight - 8 > 0;
    _highlighted = _indexOfValue();
    _entry = OverlayEntry(builder: (context) => _buildMenu(context));
    Overlay.of(context, rootOverlay: true).insert(_entry!);
    setState(() {
      _open = true;
      _focused = true;
    });
    _anim.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_open) {
        _scrollToHighlighted();
        _focusNode.requestFocus();
      }
    });
  }

  void _closeMenu() {
    if (!_open) return;
    setState(() => _open = false);
    _anim.reverse().whenComplete(_removeEntry);
  }

  void _removeEntry() {
    _entry?.remove();
    _entry = null;
  }

  void _scrollToHighlighted() {
    final maxScroll = widget.items.length * _optionHeight + 12 - _menuMaxHeight;
    if (maxScroll <= 0) {
      return;
    }
    _menuController.jumpTo(
      (_highlighted * _optionHeight).clamp(0.0, maxScroll),
    );
  }

  void _selectIndex(int index) {
    if (!_open || index < 0 || index >= widget.items.length) {
      return;
    }
    final item = widget.items[index];
    _closeMenu();
    if (item.value != widget.value) {
      widget.onChanged?.call(item.value);
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _open) {
      _closeMenu();
      return KeyEventResult.handled;
    }
    if (!_open) {
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp) {
        _openMenu();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlighted = math.min(_highlighted + 1, widget.items.length - 1);
      });
      _scrollToHighlighted();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlighted = math.max(_highlighted - 1, 0);
      });
      _scrollToHighlighted();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.select) {
      _selectIndex(_highlighted);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMenu(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CompositedTransformFollower(
      link: _layerLink,
      targetAnchor: _menuUp ? Alignment.topLeft : Alignment.bottomLeft,
      followerAnchor: _menuUp ? Alignment.bottomLeft : Alignment.topLeft,
      offset: Offset(0, _menuUp ? -6 : 6),
      showWhenUnlinked: false,
      child: FadeTransition(
        opacity: _anim,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.96,
            end: 1,
          ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic)),
          alignment: _menuUp ? Alignment.bottomCenter : Alignment.topCenter,
          child: TapRegion(
            groupId: _groupId,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: math.max(_menuWidth, 140),
                constraints: const BoxConstraints(maxHeight: _menuMaxHeight),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SingleChildScrollView(
                    controller: _menuController,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.items.length; i++)
                          _AdminDropdownOption(
                            label: widget.items[i].label,
                            selected: widget.items[i].value == widget.value,
                            highlighted: i == _highlighted,
                            onTap: () => _selectIndex(i),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget field = Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      onFocusChange: (value) => setState(() => _focused = value),
      child: TapRegion(
        groupId: _groupId,
        onTapOutside: (_) => _closeMenu(),
        child: CompositedTransformTarget(
          link: _layerLink,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _open ? _closeMenu : _openMenu,
              child: InputDecorator(
                isFocused: _focused || _open,
                decoration: InputDecoration(
                  labelText: widget.label,
                  suffixText:
                      widget.suffixText == null || widget.suffixText!.isEmpty
                          ? null
                          : widget.suffixText,
                  filled: true,
                  fillColor: colors.surfaceContainerLow.withValues(alpha: 0.6),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
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
                      turns: _open ? 0.5 : 0,
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
          ),
        ),
      ),
    );
    if (widget.width != null) {
      field = SizedBox(width: widget.width, child: field);
    }
    return field;
  }
}

/// 展开菜单中的单个选项：hover/键盘高亮、选中项主色加粗并带勾选标记。
class _AdminDropdownOption extends StatefulWidget {
  const _AdminDropdownOption({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_AdminDropdownOption> createState() => _AdminDropdownOptionState();
}

class _AdminDropdownOptionState extends State<_AdminDropdownOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = _hovered || widget.highlighted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? colors.onSurface.withValues(alpha: 0.06) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.selected ? colors.primary : colors.onSurface,
                    fontWeight:
                        widget.selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.selected)
                Icon(Icons.check_rounded, size: 16, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
