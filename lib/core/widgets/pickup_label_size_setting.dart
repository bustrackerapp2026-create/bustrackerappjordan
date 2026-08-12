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
    // إعادة بناء فقط عند تغيّر الحجم المحدد
    final size = context.select<PickupLabelScaleProvider, PickupLabelSize>(
      (p) => p.size,
    );

    return ListTile(
      leading: const Icon(Icons.text_increase, color: AppTheme.primaryColor),
      title: Text(
        l10n.pickupLabelSizeTitle,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${l10n.pickupLabelSizeHint}\n${_labelFor(l10n, size)}'),
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
    final messenger = ScaffoldMessenger.of(context);

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
                // عزل طبقة الرسم للمنتقي عن بقية الورقة (تمرير / ظل)
                RepaintBoundary(
                  child: PickupLabelSizePicker(
                    onSelected: () {
                      if (ctx.mounted) Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l10n.pickupLabelSizeChanged),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// منتقي بصري لحجم النص — 4 بطاقات خفيفة الأداء.
class PickupLabelSizePicker extends StatelessWidget {
  final VoidCallback? onSelected;

  const PickupLabelSizePicker({super.key, this.onSelected});

  static const _sizes = PickupLabelSize.values;
  static const _sampleFonts = <double>[14, 18, 22, 28];
  static const _gap = SizedBox(width: 8);
  static const _cardHeight = 92.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final labels = <String>[
      l10n.pickupLabelSizeNormal,
      l10n.pickupLabelSizeLarge,
      l10n.pickupLabelSizeXLarge,
      l10n.pickupLabelSizeXXLarge,
    ];

    // طبقة رسم واحدة للصف كاملاً — أنسب من 4 طبقات لبطاقات صغيرة
    return RepaintBoundary(
      child: SizedBox(
        height: _cardHeight,
        child: Row(
          children: [
            for (var i = 0; i < _sizes.length; i++) ...[
              if (i > 0) _gap,
              Expanded(
                child: _SizeCard(
                  size: _sizes[i],
                  label: labels[i],
                  sampleFontSize: _sampleFonts[i],
                  isDark: isDark,
                  onSurface: onSurface,
                  onSelected: onSelected,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SizeCard extends StatelessWidget {
  final PickupLabelSize size;
  final String label;
  final double sampleFontSize;
  final bool isDark;
  final Color onSurface;
  final VoidCallback? onSelected;

  const _SizeCard({
    required this.size,
    required this.label,
    required this.sampleFontSize,
    required this.isDark,
    required this.onSurface,
    this.onSelected,
  });

  static const _radius = BorderRadius.all(Radius.circular(14));
  static const _padding = EdgeInsets.symmetric(vertical: 10, horizontal: 4);

  static final _bgSelectedLight =
      AppTheme.primaryColor.withValues(alpha: 0.10);
  static final _bgSelectedDark =
      AppTheme.primaryColor.withValues(alpha: 0.22);
  static final _bgIdleDark = Colors.white.withValues(alpha: 0.06);
  static final _borderIdle = Colors.grey.shade300;

  @override
  Widget build(BuildContext context) {
    // كل بطاقة تُعاد بناؤها فقط إذا تغيّرت حالة اختيارها
    final selected = context.select<PickupLabelScaleProvider, bool>(
      (p) => p.size == size,
    );

    final bg = selected
        ? (isDark ? _bgSelectedDark : _bgSelectedLight)
        : (isDark ? _bgIdleDark : Colors.grey.shade50);
    final borderColor = selected ? AppTheme.primaryColor : _borderIdle;
    final sampleColor = selected ? AppTheme.primaryColor : onSurface;
    final labelColor =
        selected ? AppTheme.primaryColor : onSurface.withValues(alpha: 0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final provider = context.read<PickupLabelScaleProvider>();
          await provider.setSize(size);
          onSelected?.call();
        },
        borderRadius: _radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: _radius,
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1.2,
            ),
          ),
          child: Padding(
            padding: _padding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Text(
                      'أ',
                      style: TextStyle(
                        fontSize: sampleFontSize,
                        fontWeight: FontWeight.w800,
                        color: sampleColor,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: labelColor,
                  ),
                ),
                SizedBox(
                  height: 16,
                  child: selected
                      ? const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppTheme.primaryColor,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
