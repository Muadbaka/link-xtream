import 'package:flutter/material.dart';

import '../core/theme.dart';

/// رأس الصفحة الموحد — مطابق لمكوّن PageHeader في الويب:
/// مربع أيقونة بلون العلامة + عنوان غامق + وصف صغير + أزرار إجراءات،
/// بشريط سفلي وخلفية البطاقة.
class PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final List<Widget> actions;

  const PageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.card(scheme.brightness == Brightness.dark),
        border: Border(bottom: BorderSide(color: scheme.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.25)),
                if (description != null)
                  Text(description!,
                      style: TextStyle(
                          fontSize: 11.5,
                          color: scheme.onSurfaceVariant,
                          height: 1.4)),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...actions,
          ],
        ],
      ),
    );
  }
}
