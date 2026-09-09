import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/site_store.dart';

/// Passive app-bar label showing the manager's active property name.
/// Switching happens from the dock bar (BottomMenuBar left shoulder).
class ActivePropertyLabel extends StatelessWidget {
  const ActivePropertyLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final site = context.watch<SiteStore>();
    final active = site.activeProperty;
    final narrow = MediaQuery.sizeOf(context).width < 400;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 4 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.apartment, size: 18),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: narrow ? 72 : 140),
            child: Text(
              active?.name ?? 'No property',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
