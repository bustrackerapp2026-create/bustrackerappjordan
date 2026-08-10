import 'package:flutter/material.dart';

import '../../core/widgets/app_top_bar.dart';

/// شريط السائق — يعتمد على [AppTopBar] الموحّد.
class DriverCustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DriverCustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTopBar.user(fallbackInitial: 'س');
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
