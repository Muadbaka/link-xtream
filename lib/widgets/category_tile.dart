import 'package:flutter/material.dart';

/// عنصر فئة في القائمة الجانبية — نفس نمط شاشة البث المباشر
class CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const CategoryTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      selected: selected,
      leading: Icon(icon, size: 18, color: selected ? scheme.primary : null),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
