import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';

/// ملصق شبكي مع تدرج بديل أنيق عند غياب الصورة
class Poster extends StatelessWidget {
  final String url;
  final String title;
  final double? width;
  final double? height;
  final BorderRadius radius;
  final String? idForTint;

  const Poster({
    super.key,
    required this.url,
    required this.title,
    this.width,
    this.height,
    this.radius = const BorderRadius.all(Radius.circular(12)),
    this.idForTint,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url.startsWith('http');
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: hasUrl
            ? Image.network(
                url,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _fallback(),
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: const Center(
                        child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )),
                  );
                },
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final (a, b) = posterTint(idForTint ?? title);
    final initial = title.isNotEmpty ? title.characters.first : '?';
    return DecoratedBox(
      decoration:
          BoxDecoration(gradient: LinearGradient(colors: [Color(a), Color(b)])),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_outlined, color: Colors.white70, size: 30),
            const SizedBox(height: 6),
            Text(
              initial,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// شارة صغيرة (تقييم، جودة، تجريبي...)
class Badge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const Badge(this.label, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: c, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// قسم عنوان داخل الشاشات
class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// حالة فراغ / خطأ موحّدة
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const EmptyState(
      {super.key, required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 54, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
