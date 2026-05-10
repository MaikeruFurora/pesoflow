import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Subtle 3-dot context menu used at the end of any row that needs
/// edit/delete (or other) actions. Replaces swipe-to-action across the app
/// for a cleaner, more discoverable affordance.
class RowMoreMenu extends StatelessWidget {
  const RowMoreMenu({
    super.key,
    this.onEdit,
    this.onDelete,
    this.extra = const [],
  });

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Optional additional actions appended below Edit (before Delete).
  final List<RowAction> extra;

  @override
  Widget build(BuildContext context) {
    final items = <PopupMenuEntry<int>>[];
    var i = 0;
    if (onEdit != null) {
      items.add(PopupMenuItem(
        value: i++,
        child: const _MenuRow(
          icon: Icons.edit_outlined,
          color: AppColors.primary,
          label: 'Edit',
        ),
      ));
    }
    for (final a in extra) {
      items.add(PopupMenuItem(
        value: i++,
        child: _MenuRow(
          icon: a.icon,
          color: a.color ?? AppColors.primary,
          label: a.label,
        ),
      ));
    }
    if (onDelete != null) {
      if (items.isNotEmpty) items.add(const PopupMenuDivider(height: 4));
      items.add(PopupMenuItem(
        value: i++,
        child: const _MenuRow(
          icon: Icons.delete_outline,
          color: AppColors.danger,
          label: 'Delete',
          labelColor: AppColors.danger,
        ),
      ));
    }

    final actions = <VoidCallback>[
      if (onEdit != null) onEdit!,
      ...extra.map((a) => a.onTap),
      if (onDelete != null) onDelete!,
    ];

    return PopupMenuButton<int>(
      tooltip: 'More',
      icon: Icon(
        Icons.more_horiz_rounded,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
      ),
      offset: const Offset(0, 36),
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (v) => actions[v](),
      itemBuilder: (_) => items,
    );
  }
}

class RowAction {
  const RowAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.label,
    this.labelColor,
  });
  final IconData icon;
  final Color color;
  final String label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: labelColor),
        ),
      ],
    );
  }
}

/// Tinted circular icon button for use in AppBar actions — softer and more
/// modern than the default IconButton on a flat background.
class AppBarIconAction extends StatelessWidget {
  const AppBarIconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.danger = false,
  });
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: color.withOpacity(0.10),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 38,
              height: 38,
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
