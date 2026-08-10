import 'package:flutter/material.dart';

import '../../core/widgets/app_top_bar.dart';

/// شريط الراكب — يعتمد على [AppTopBar] الموحّد.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppTopBar.user(fallbackInitial: 'ر');
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
