import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/widgets/mobile_shell_scope.dart';
import 'package:omninest/core/widgets/responsive_breakpoints.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop_policy.dart';
import 'package:omninest/features/backdrop/backdrop_ui.dart';
import 'package:omninest/features/portal/application/portal_dashboard_providers.dart';
import 'package:omninest/features/portal/presentation/widgets/portal_desktop_visual_shells.dart';
import 'package:omninest/features/portal/presentation/widgets/portal_mobile_shell.dart';

class PortalPage extends ConsumerStatefulWidget {
  const PortalPage({super.key});

  @override
  ConsumerState<PortalPage> createState() => _PortalPageState();
}

/// Portal 宿主：负责摘要数据的及时同步。
///
/// 三条刷新路径均为节流驱动：进入页面时（仅重进，跳过首次加载）、窗口
/// 重新聚焦时（30 秒节流），以及实时脏范围订阅（由
/// [portalDashboardRealtimeBinderProvider] 承载，页面挂载期间存活）。
/// 不做定时轮询：协调器的周期同步会把离线期间漏掉的推送以脏范围补发。
class _PortalPageState extends ConsumerState<PortalPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(portalDashboardActionsProvider).refreshOnEntry());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(portalDashboardActionsProvider).maybeRefreshAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    // 挂载期间订阅实时脏范围；autoDispose 保证离开页面即取消。
    ref.watch(portalDashboardRealtimeBinderProvider);
    final isCompact = ResponsiveBreakpoints.isCompact(
      MediaQuery.sizeOf(context).width,
    );
    final policy =
        isCompact ? AppBackdropPolicy.portalMobile : AppBackdropPolicy.portal;
    final content = Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = !ResponsiveBreakpoints.isCompact(constraints.maxWidth);
          if (!isWide) {
            return const PortalMobileShell();
          }
          return const PortalDesktopVisualHost();
        },
      ),
    );
    if (MobileShellScope.isHosted(context)) {
      return content;
    }
    return AppBackdropSceneScope(
      owner: 'portal',
      policy: policy,
      child: content,
    );
  }
}
