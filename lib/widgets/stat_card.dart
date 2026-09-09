import 'package:flutter/material.dart';

import '../utils/money.dart';

/// A polished KPI tile: circular icon badge with glow, right-aligned value
/// with separated currency symbol, and muted label.
/// Shared by the dashboard and finance grids so they stay visually identical.
class StatCard extends StatelessWidget {
  final String label;
  final int cents;
  final String currency;
  final IconData icon;
  final Color color;
  final bool plain;
  final VoidCallback? onTap;
  final String? caption;

  const StatCard({
    super.key,
    required this.label,
    required this.cents,
    required this.currency,
    required this.icon,
    required this.color,
    this.plain = false,
    this.onTap,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final sym = moneySymbol(currency);
    final numStr = moneyNumber(cents);

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icon badge ──
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.06),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          // ── Text block ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plain)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$cents',
                      style: (textTheme.headlineSmall ?? const TextStyle()).copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        flex: 0,
                        child: Text(
                          sym,
                          style: (textTheme.titleMedium ?? const TextStyle()).copyWith(
                            color: color.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            numStr,
                            maxLines: 1,
                            style: (textTheme.headlineSmall ?? const TextStyle()).copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 2),
                // Label
                Text(
                  label,
                  style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    caption!,
                    style: (textTheme.bodySmall ?? const TextStyle()).copyWith(
                      color: color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return onTap != null
        ? GestureDetector(onTap: onTap, child: card)
        : card;
  }
}
