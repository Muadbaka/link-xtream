import 'dart:io';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/updater.dart';

/// يعرض نافذة التحقق من التحديثات وتنزيلها
Future<void> showUpdateDialog(BuildContext context, {bool manual = true}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _UpdateDialogView(),
  );
}

class _UpdateDialogView extends StatefulWidget {
  const _UpdateDialogView();

  @override
  State<_UpdateDialogView> createState() => _UpdateDialogViewState();
}

enum _Step { checking, upToDate, available, downloading, error }

class _UpdateDialogViewState extends State<_UpdateDialogView> {
  _Step _step = _Step.checking;
  UpdateInfo? _update;
  String? _errorMsg;

  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _step = _Step.checking;
      _errorMsg = null;
    });

    try {
      final update = await UpdateService.checkForUpdate();
      if (!mounted) return;
      if (update != null) {
        setState(() {
          _update = update;
          _step = _Step.available;
        });
      } else {
        setState(() {
          _step = _Step.upToDate;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _Step.error;
        _errorMsg = e.toString().replaceFirst('Exception: ', '').replaceFirst('HttpException: ', '');
      });
    }
  }

  Future<void> _startDownload() async {
    final update = _update;
    if (update == null || update.downloadUrl.isEmpty) return;

    setState(() {
      _step = _Step.downloading;
      _progress = 0.0;
      _receivedBytes = 0;
      _totalBytes = 0;
      _cancelled = false;
    });

    try {
      await UpdateService.downloadAndInstall(
        downloadUrl: update.downloadUrl,
        isCancelled: () => _cancelled,
        onProgress: (p, received, total) {
          if (mounted) {
            setState(() {
              _progress = p;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );
    } catch (e) {
      if (!mounted || _cancelled) return;
      setState(() {
        _step = _Step.error;
        _errorMsg = 'تعذر إكمال التنزيل: ${e.toString()}';
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 ميغابايت';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} ميغابايت';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: switch (_step) {
          _Step.checking => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                CircularProgressIndicator(color: AppTheme.brand),
                const SizedBox(height: 20),
                const Text(
                  'جارٍ التحقق من التحديثات...',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  'يتم الاتصال بخادم التحديثات لمقارنة الإصدار الحالي (v${UpdateService.currentVersion})',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
              ],
            ),
          _Step.upToDate => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.brand.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: AppTheme.brand, size: 32),
                ),
                const SizedBox(height: 14),
                const Text(
                  'التطبيق محدّث بالكامل',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'أنت تستخدم بالفعل أحدث إصدار متوفر (v${UpdateService.currentVersion})',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
              ],
            ),
          _Step.error => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_off_rounded,
                      color: scheme.error, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'تعذر التحقق من التحديث',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  _errorMsg ?? 'تأكد من اتصالك بالإنترنت وحاول مرة أخرى.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
              ],
            ),
          _Step.available => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.system_update_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'إصدار جديد متوفر: v${_update?.version ?? ""}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.brand.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'جديد',
                                  style: TextStyle(
                                      color: AppTheme.brand,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'الإصدار الحالي: v${UpdateService.currentVersion}${_update?.releaseDate.isNotEmpty == true ? " • ${_update!.releaseDate}" : ""}',
                            style: TextStyle(
                                fontSize: 11.5, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if ((_update?.changelog ?? []).isNotEmpty) ...[
                  const Text('أبرز التحسينات والميزات الجديدة:',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _update!.changelog.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• ',
                                    style: TextStyle(
                                        color: AppTheme.brand,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(fontSize: 12, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          _Step.downloading => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.downloading_rounded,
                        color: AppTheme.brand, size: 24),
                    const SizedBox(width: 8),
                    const Text('جارٍ تنزيل التحديث...',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    const Spacer(),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          color: AppTheme.brand,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    minHeight: 8,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: AppTheme.brand,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatBytes(_receivedBytes),
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                    if (_totalBytes > 0)
                      Text(
                        _formatBytes(_totalBytes),
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'سيتم إغلاق التطبيق وتشغيل معالج التثبيت تلقائياً بمجرد اكتمال التنزيل.',
                  style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      height: 1.4),
                ),
              ],
            ),
        },
      ),
      actions: [
        switch (_step) {
          _Step.checking => const SizedBox.shrink(),
          _Step.upToDate => FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('حسناً'),
            ),
          _Step.error => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                FilledButton.tonal(
                  onPressed: _check,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          _Step.available => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('لاحقاً'),
                ),
                FilledButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('تحديث وتثبيت الآن'),
                ),
              ],
            ),
          _Step.downloading => TextButton(
              onPressed: () {
                _cancelled = true;
                Navigator.of(context).pop();
              },
              child: const Text('إلغاء التنزيل'),
            ),
        },
      ],
    );
  }
}
