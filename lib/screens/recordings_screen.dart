import 'package:flutter/material.dart' hide Badge;
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../state/app_state.dart';
import '../widgets/page_header.dart';
import '../widgets/poster.dart' show Badge;

/// التسجيلات — تسجيل حقيقي للبث إلى القرص (TS)
class RecordingsScreen extends StatelessWidget {
  const RecordingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            icon: Icons.radio_button_checked_outlined,
            title: 'التسجيلات',
            description:
                'ابدأ التسجيل من زر «تسجيل» داخل المشغل — يُحفظ التدفق خاماً بصيغة TS قابلة للتشغيل بأي مشغل',
            actions: [
              if (st.hasActiveRecording)
                const Badge('جارٍ التسجيل الآن',
                    icon: Icons.fiber_manual_record, color: Colors.redAccent),
            ],
          ),
          const SizedBox(height: 6),
          if (st.recordings.isNotEmpty)
            Text('مجلد الحفظ: ${st.recordingsDir}',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Expanded(
            child: st.recordings.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.radio_button_unchecked_outlined,
                            size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('لا توجد تسجيلات بعد'),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: st.recordings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final r = st.recordings[i];
                      final bytes = st.recordingBytes[r.id] ?? 0;
                      return Card(
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          leading: Icon(
                            r.status == 'recording'
                                ? Icons.fiber_manual_record
                                : r.status == 'failed'
                                    ? Icons.error_outline
                                    : r.status == 'cancelled'
                                        ? Icons.cancel_outlined
                                        : Icons.task_alt_outlined,
                            color: r.status == 'recording'
                                ? Colors.redAccent
                                : r.status == 'failed'
                                    ? scheme.error
                                    : r.status == 'cancelled'
                                        ? scheme.onSurfaceVariant
                                        : AppTheme.brand,
                          ),
                          title: Text(
                            '${r.channelName} — ${r.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            '${_statusText(r.status)}  •  ${Fmt.date(r.createdAt.millisecondsSinceEpoch ~/ 1000)}'
                            '${r.status == 'recording' && bytes > 0 ? '  •  ${(bytes / 1048576).toStringAsFixed(1)} MB' : ''}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r.status == 'recording' ||
                                  r.status == 'scheduled')
                                OutlinedButton.icon(
                                  onPressed: () => st.stopRecording(r.id),
                                  icon:
                                      const Icon(Icons.stop_rounded, size: 17),
                                  label: const Text('إيقاف'),
                                ),
                              IconButton(
                                tooltip: 'حذف من القائمة',
                                onPressed: () => st.removeRecording(r.id),
                                icon: Icon(Icons.delete_outline,
                                    color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _statusText(String status) => switch (status) {
        'recording' => 'جارٍ التسجيل',
        'scheduled' => 'مجدول',
        'done' => 'مكتمل',
        'failed' => 'فشل',
        'cancelled' => 'ملغى',
        _ => status,
      };
}
