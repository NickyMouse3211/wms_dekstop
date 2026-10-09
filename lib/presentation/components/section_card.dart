import 'package:flutter/material.dart';

import '../../core/constants/wms_theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.trailing,
    this.collapsible = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    if (collapsible) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: ValueKey('settings-section-$title'),
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: icon == null ? null : Icon(icon, color: WmsColors.primary),
          title: Text(title, style: Theme.of(context).textTheme.titleLarge),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          children: [
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing),
            child,
          ],
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: WmsColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: WmsColors.primary, size: 21),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
