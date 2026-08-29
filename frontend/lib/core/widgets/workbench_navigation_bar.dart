import 'package:flutter/material.dart';

/// 工作台窄屏底部导航，使用 Material 导航语义和稳定目标尺寸。
class WorkbenchNavigationBar extends StatelessWidget {
  const WorkbenchNavigationBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<WorkbenchNavigationItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: onTap,
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
                tooltip: item.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

/// 工作台底部导航项。
class WorkbenchNavigationItem {
  const WorkbenchNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
