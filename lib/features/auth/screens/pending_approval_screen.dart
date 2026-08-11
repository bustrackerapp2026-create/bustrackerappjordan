import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userData = authProvider.userData;

        final isRejected = userData?.isRejected == true;
        final title = isRejected ? l10n.rejectedTitle : l10n.pendingTitle;
        final message = isRejected ? l10n.rejectedMessage : l10n.pendingMessage;
        final icon =
            isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded;
        final iconColor = isRejected ? Colors.red : Colors.orange;

        return Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 80, color: iconColor),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.read<AuthProvider>().signOut(),
                    child: Text(l10n.logout),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
