import 'package:flutter/material.dart';

/// 侧边点击区域。
///
/// Listener 不参与手势竞技场，允许 SelectionArea 正常接收点击事件。
/// 用距离检测区分点击（<18px）和滚动（>=18px）。
class SideTapZone extends StatefulWidget {
  const SideTapZone({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  State<SideTapZone> createState() => SideTapZoneState();
}

class SideTapZoneState extends State<SideTapZone> {
  Offset? _downPosition;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _downPosition = event.buttons == 1 ? event.position : null;
      },
      onPointerUp: (event) {
        if (_downPosition == null) return;
        final distance = (event.position - _downPosition!).distance;
        _downPosition = null;
        if (distance < 18) widget.onTap();
      },
      onPointerCancel: (_) => _downPosition = null,
      child: const SizedBox.expand(),
    );
  }
}
