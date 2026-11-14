import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// يتحقق من قفل الفئة ويطلب الرقم السري عند الحاجة.
/// يعيد true إذا كان المحتوى متاحاً (غير مقفل أو تم فتحه بنجاح).
Future<bool> ensureCategoryUnlocked(
  BuildContext context,
  AppState st,
  FavKind kind,
  String categoryId,
) async {
  if (!st.isCategoryLocked(kind, categoryId)) return true;
  if (!context.mounted) return false;

  final controller = TextEditingController();
  String? error;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('فئة محمية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هذه الفئة محمية بالرقم السري للرقابة الأبوية'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) {
                if (st.unlock(controller.text)) Navigator.pop(ctx, true);
              },
              decoration: InputDecoration(
                labelText: 'الرقم السري',
                errorText: error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (st.unlock(controller.text)) {
                Navigator.pop(ctx, true);
              } else {
                setDialogState(() => error = 'الرقم السري غير صحيح');
              }
            },
            child: const Text('فتح'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return accepted == true;
}
