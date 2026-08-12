import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../map/pickup_label_scale_provider.dart';
import '../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// بلاطة إعدادات لاختيار حجم نص نقاط التجمع (لكل الشاشات).
class PickupLabelSizeTile extends StatelessWidget {
  const PickupLabelSizeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<PickupLabelScaleProvider>();
    final subtitle = switch (provider.size) {
      PickupLabelSize.normal => l10n.pickupLabelSizeNormal,
      PickupLabelSize.large => l10n.pickupLabelSizeLarge,
      PickupLabelSize.xlarge => l10n.pickupLabelSizeXLarge,
    };

    return ListTile(
      leading: const Icon(Icons.text_increase, color: AppTheme.primaryColor),
      title: Text(
        l10n.pickupLabelSizeTitle,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${l10n.pickupLabelSizeHint}\n$subtitle'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_left),
      onTap: () => _openSheet(context),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<PickupLabelScaleProvider>();

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.pickupLabelSizeTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.pickupLabelSizeHint,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                for (final size in PickupLabelSize.values)
                  ListTile(
                    leading: Icon(
                      size == PickupLabelSize.normal
                          ? Icons.text_fields
                          : Icons.format_size,
                      color: AppTheme.primaryColor,
                      size: size == PickupLabelSize.xlarge
                          ? 28
                          : (size == PickupLabelSize.large ? 24 : 20),
                    ),
                    title: Text(
                      size == PickupLabelSize.normal
                          ? l10n.pickupLabelSizeNormal
                          : size == PickupLabelSize.large
                              ? l10n.pickupLabelSizeLarge
                              : l10n.pickupLabelSizeXLarge,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: provider.size == size
                        ? const Icon(Icons.check, color: AppTheme.primaryColor)
                        : null,
                    onTap: () async {
                      await provider.setSize(size);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.pickupLabelSizeChanged),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
