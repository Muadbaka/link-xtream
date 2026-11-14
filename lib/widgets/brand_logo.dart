import 'package:flutter/material.dart';

import '../core/theme.dart';

/// شعار Link Xtream — بلاطة زمردية متدرجة بمثلث تشغيل أبيض
/// (مطابق تماماً لأيقونة التطبيق windows/runner/resources/app_icon.ico)
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandDeep.withValues(alpha: 0.45),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // مثلث التشغيل — يشير لليسار (يتوافق مع اتجاه RTL)
    // نفس هندسة أيقونة التطبيق: مثلث أبيض فقط فوق البلاطة المتدرجة
    final triPath = Path()
      ..moveTo(w * 0.30, h * 0.30)
      ..lineTo(w * 0.72, h * 0.52)
      ..lineTo(w * 0.30, h * 0.74)
      ..close();
    canvas.drawPath(
      triPath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// شعار نصي: Link (أبيض/أسود) + Xtream (زمردي)
class BrandWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;
  const BrandWordmark({super.key, this.fontSize = 26, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        style: TextStyle(fontFamily: 'Tajawal', fontSize: fontSize),
        children: [
          TextSpan(
            text: 'Link ',
            style: TextStyle(
                color: color ?? scheme.onSurface, fontWeight: FontWeight.w900),
          ),
          TextSpan(
            text: 'Xtream',
            style: const TextStyle(
                color: AppTheme.brand, fontWeight: FontWeight.w900),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    );
  }
}
