import 'package:flutter/material.dart';
import 'package:omninest/core/widgets/mobile_shell_scope.dart';
import 'package:omninest/core/widgets/responsive_breakpoints.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop_policy.dart';
import 'package:omninest/features/backdrop/backdrop_ui.dart';
import 'package:omninest/features/portal/presentation/widgets/portal_desktop_visual_shells.dart';
import 'package:omninest/features/portal/presentation/widgets/portal_mobile_shell.dart';

class PortalPage extends StatelessWidget {
  const PortalPage({super.key});

  @override
  Widget build(BuildContext context) {
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
