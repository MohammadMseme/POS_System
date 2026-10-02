import 'dart:io';

import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../services/hive_service.dart';

/// Opens the smart-backup dialog (drive choice -> progress -> result).
///
/// Everything happens inside ONE self-contained dialog widget, so there is
/// no chain of dialogs being pushed/popped around async work (the source
/// of the lifecycle crashes fixed earlier). While the backup is running
/// the dialog cannot be dismissed.
Future<void> showSmartBackupDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SmartBackupDialog(),
  );
}

enum _Phase { loadingDrives, choosing, running, done, failed }

class _SmartBackupDialog extends StatefulWidget {
  const _SmartBackupDialog();

  @override
  State<_SmartBackupDialog> createState() => _SmartBackupDialogState();
}

class _SmartBackupDialogState extends State<_SmartBackupDialog> {
  _Phase _phase = _Phase.loadingDrives;
  List<BackupDrive> _drives = const [];
  BackupDrive? _selected;
  BackupReport? _report;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Started after the first frame: setState() must not run while
    // initState() is still executing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDrives());
  }

  Future<void> _loadDrives() async {
    if (!mounted) return;
    if (!Platform.isWindows) {
      setState(() {
        _phase = _Phase.failed;
        _error = 'النسخ الاحتياطي للفلاشة متاح على نسخة ويندوز فقط.';
      });
      return;
    }
    setState(() => _phase = _Phase.loadingDrives);
    final drives = await BackupService.listDrives();
    if (!mounted) return;
    setState(() {
      _drives = drives;
      // Prefer a drive that already holds our backup, else a flash drive.
      _selected = drives.isNotEmpty ? drives.first : null;
      _phase = _Phase.choosing;
    });
  }

  Future<void> _start() async {
    final drive = _selected;
    if (drive == null) return;
    setState(() => _phase = _Phase.running);
    try {
      final report = await BackupService.backupTo(drive);
      if (!mounted) return;
      setState(() {
        _report = report;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر إكمال النسخ الاحتياطي: $e\n'
            'تأكد أن الفلاشة/الهارد ما زال موصولاً وغير محمي ضد الكتابة.';
        _phase = _Phase.failed;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bool busy = _phase == _Phase.running || _phase == _Phase.loadingDrives;

    return PopScope(
      canPop: _phase != _Phase.running,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.sd_storage_outlined, color: Color(0xFF1565C0)),
            SizedBox(width: 10),
            Expanded(
              child: Text('نسخ احتياطي ذكي للفلاشة / الهارد الخارجي',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ),
          ],
        ),
        content: SizedBox(width: 480, child: _buildContent()),
        actions: _buildActions(busy),
      ),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case _Phase.loadingDrives:
        return const _Busy(text: 'جارٍ البحث عن الأقراص الموصولة...');
      case _Phase.running:
        return _Busy(
          text: 'جارٍ النسخ إلى ${_selected?.displayName ?? ''}...\n'
              'لا تنزع الفلاشة حتى انتهاء العملية.',
        );
      case _Phase.failed:
        return Text(_error ?? 'حدث خطأ غير متوقع', style: TextStyle(color: Colors.red.shade700));
      case _Phase.done:
        return _buildReport(_report!);
      case _Phase.choosing:
        return _buildDriveList();
    }
  }

  Widget _buildDriveList() {
    if (_drives.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'لم يتم العثور على فلاشة أو هارد خارجي.',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
          ),
          const SizedBox(height: 6),
          const Text('قم بتوصيل الفلاشة أو الهارد الخارجي ثم اضغط "تحديث".'),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اختر القرص الذي سيتم النسخ إليه:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: ListView(
            shrinkWrap: true,
            children: _drives.map((d) {
              final bool selected = d.root == _selected?.root;
              final details = <String>[
                d.isRemovable ? 'فلاشة / قرص قابل للإزالة' : (d.driveType == 3 ? 'قرص ثابت / هارد خارجي' : 'قرص'),
                if (d.freeBytes != null) 'متاح ${BackupService.formatBytes(d.freeBytes!)}',
              ];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: selected ? const Color(0xFF1565C0).withValues(alpha: 0.06) : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? const Color(0xFF1565C0) : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  onTap: () => setState(() => _selected = d),
                  leading: Icon(
                    d.isRemovable ? Icons.usb_rounded : Icons.storage_rounded,
                    color: selected ? const Color(0xFF1565C0) : Colors.grey.shade600,
                  ),
                  title: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    details.join(' • ') +
                        (d.hasExistingBackup
                            ? '\nيحتوي نسخة سابقة${d.lastBackupAt != null ? ' (آخر نسخ: ${_formatDate(d.lastBackupAt!)})' : ''} - سيتم نسخ الجديد فقط'
                            : '\nلا توجد نسخة سابقة - سيتم إنشاء نسخة كاملة'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: Color(0xFF1565C0))
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'مجلد البيانات الحالي: ${_safeDataPath()}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  String _safeDataPath() {
    try {
      return HiveService.dataDirectory.path;
    } catch (_) {
      return '-';
    }
  }

  Widget _buildReport(BackupReport r) {
    final bool hasErrors = r.errors.isNotEmpty;
    final Color color = hasErrors ? Colors.orange.shade800 : Colors.green.shade700;

    String headline;
    if (hasErrors) {
      headline = 'اكتمل النسخ مع بعض الأخطاء';
    } else if (r.nothingNew) {
      headline = 'النسخة على القرص محدثة - لا توجد بيانات جديدة لنسخها';
    } else if (r.isFirstBackup) {
      headline = 'تم إنشاء النسخة الاحتياطية بنجاح';
    } else {
      headline = 'تمت إضافة البيانات الجديدة إلى النسخة السابقة بنجاح';
    }

    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700))),
              Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(hasErrors ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(headline, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (r.previousBackupAt != null) line('آخر نسخة سابقة', _formatDate(r.previousBackupAt!)),
        line('ملفات أُضيفت لها السجلات الجديدة فقط', '${r.appendedFiles}'),
        line('ملفات نُسخت بالكامل', '${r.copiedFiles}'),
        line('ملفات بدون تغيير (لم تُنسخ)', '${r.unchangedFiles}'),
        line('حجم البيانات المكتوبة', BackupService.formatBytes(r.bytesWritten)),
        const SizedBox(height: 6),
        Text('المسار: ${r.backupPath}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        if (hasErrors) ...[
          const SizedBox(height: 8),
          Text(r.errors.join('\n'), style: TextStyle(fontSize: 11.5, color: Colors.red.shade700)),
        ],
      ],
    );
  }

  List<Widget> _buildActions(bool busy) {
    switch (_phase) {
      case _Phase.loadingDrives:
      case _Phase.running:
        return const [];
      case _Phase.done:
      case _Phase.failed:
        return [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ];
      case _Phase.choosing:
        return [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton.icon(
            onPressed: _loadDrives,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث'),
          ),
          ElevatedButton.icon(
            onPressed: (_selected == null || busy) ? null : _start,
            icon: const Icon(Icons.backup_outlined),
            label: const Text('بدء النسخ'),
          ),
        ];
    }
  }
}

class _Busy extends StatelessWidget {
  final String text;

  const _Busy({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(width: 16),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
