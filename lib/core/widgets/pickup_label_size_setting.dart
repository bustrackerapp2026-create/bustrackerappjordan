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
    final subtitle = _labelFor(l10n, provider.size);

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

  static String _labelFor(AppLocalizations l10n, PickupLabelSize size) {
    switch (size) {
      case PickupLabelSize.normal:
        return l10n.pickupLabelSizeNormal;
      case PickupLabelSize.large:
        return l10n.pickupLabelSizeLarge;
      case PickupLabelSize.xlarge:
        return l10n.pickupLabelSizeXLarge;
      case PickupLabelSize.xxlarge:
        return l10n.pickupLabelSizeXXLarge;
    }
  }

  Future<void> _openSheet(BuildContext context) async {
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
                const SizedBox(height: 18),
                PickupLabelSizePicker(
                  onSelected: () {
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

/// منتقي بصري لحجم النص — 4 بطاقات تعرض حجم الحرف مباشرة.
class PickupLabelSizePicker extends StatelessWidget {
  final VoidCallback? onSelected;

  const PickupLabelSizePicker({super.key, this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<PickupLabelScaleProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        for (final size in PickupLabelSize.values) ...[
          if (size != PickupLabelSize.normal) const SizedBox(width: 8),
          Expanded(
            child: _SizeCard(
              size: size,
              label: _label(l10n, size),
              selected: provider.size == size,
              isDark: isDark,
              sampleFontSize: _sampleFont(size),
              onTap: () async {
                await provider.setSize(size);
                onSelected?.call();
              },
            ),
          ),
        ],
      ],
    );
  }

  static String _label(AppLocalizations l10n, PickupLabelSize size) {
    switch (size) {
      case PickupLabelSize.normal:
        return l10n.pickupLabelSizeNormal;
      case PickupLabelSize.large:
        return l10n.pickupLabelSizeLarge;
      case PickupLabelSize.xlarge:
        return l10n.pickupLabelSizeXLarge;
      case PickupLabelSize.xxlarge:
        return l10n.pickupLabelSizeXXLarge;
    }
  }

  static double _sampleFont(PickupLabelSize size) {
    switch (size) {
      case PickupLabelSize.normal:
        return 14;
      case PickupLabelSize.large:
        return 18;
      case PickupLabelSize.xlarge:
        return 22;
      case PickupLabelSize.xxlarge:
        return 28;
    }
  }
}

class _SizeCard extends StatelessWidget {
  final PickupLabelSize size;
  final String label;
  final bool selected;
  final bool isDark;
  final double sampleFontSize;
  final VoidCallback onTap;

  const _SizeCard({
    required this.size,
    required this.label,
    required this.selected,
    required this.isDark,
    required this.sampleFontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? AppTheme.primaryColor : Colors.grey.shade300;
    final bg = selected
        ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.22 : 0.10)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 36,
                child: Center(
                  child: Text(
                    'أ',
                    style: TextStyle(
                      fontSize: sampleFontSize,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppTheme.primaryColor
                          : Theme.of(context).colorScheme.onSurface,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? AppTheme.primaryColor
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
              ] else
                const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
