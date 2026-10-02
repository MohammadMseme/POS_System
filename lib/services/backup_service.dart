import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'hive_service.dart';

/// A drive the backup can be written to (USB flash / external disk).
class BackupDrive {
  /// Root path, e.g. `E:\`.
  final String root;
  final String volumeLabel;

  /// Windows drive type: 2 = removable (flash), 3 = fixed (external or
  /// internal disk), 0 = unknown (fallback detection).
  final int driveType;
  final int? freeBytes;
  final int? sizeBytes;

  /// The drive already holds a backup made by this app (or the old
  /// "SamaBackup" folder from earlier versions).
  final bool hasExistingBackup;
  final DateTime? lastBackupAt;

  const BackupDrive({
    required this.root,
    required this.volumeLabel,
    required this.driveType,
    this.freeBytes,
    this.sizeBytes,
    this.hasExistingBackup = false,
    this.lastBackupAt,
  });

  bool get isRemovable => driveType == 2;

  String get letter => root.replaceAll('\\', '').replaceAll('/', '');

  String get displayName =>
      volumeLabel.trim().isEmpty ? letter : '${volumeLabel.trim()} ($letter)';
}

/// Result of one backup run.
class BackupReport {
  final String backupPath;
  final DateTime finishedAt;
  final DateTime? previousBackupAt;

  /// Files that only had their new records appended.
  final int appendedFiles;

  /// Files copied completely (first backup, or Hive compacted the file).
  final int copiedFiles;

  /// Files with no new data since the last backup (nothing written).
  final int unchangedFiles;

  final int bytesWritten;
  final List<String> errors;

  const BackupReport({
    required this.backupPath,
    required this.finishedAt,
    required this.previousBackupAt,
    required this.appendedFiles,
    required this.copiedFiles,
    required this.unchangedFiles,
    required this.bytesWritten,
    required this.errors,
  });

  bool get isFirstBackup => previousBackupAt == null;
  bool get nothingNew => appendedFiles == 0 && copiedFiles == 0 && errors.isEmpty;
}

/// Smart, incremental backup of the Hive database to an external drive.
///
/// Layout on the drive:
///   X:\FikraBackup\HiveData\*.hive      <- restorable copy of the database
///   X:\FikraBackup\backup_manifest.json <- last backup time + file states
///   X:\FikraBackup\backup_log.txt       <- one line per backup run
///   X:\FikraBackup\README.txt           <- how to restore
///
/// WHY THIS IS INCREMENTAL: a Hive box file is an append-only log - new
/// records, edits and deletions are all written as new entries at the
/// END of the file. So for every box file:
///   * same size and unchanged since the last backup -> skipped entirely;
///   * the backup copy is an exact prefix of the live file -> ONLY the
///     new bytes (the records written after the last backup) are
///     appended to it - nothing already on the drive is copied again;
///   * otherwise (Hive compacted/rewrote the file, or the copy is
///     damaged) -> that one file is copied in full, safely via a temp
///     file + rename, so the previous copy is never left half-written.
/// The result is always a valid, directly restorable Hive folder.
class BackupService {
  static const String backupFolderName = 'FikraBackup';
  static const String dataSubFolder = 'HiveData';
  static const String manifestName = 'backup_manifest.json';
  static const String logName = 'backup_log.txt';

  /// Folder written by earlier versions of the app (flat copy). Used
  /// once to seed the new backup so old backups are not copied again.
  static const String legacyFolderName = 'SamaBackup';

  static const int _chunkSize = 1024 * 1024; // 1 MB

  static String get _sep => Platform.pathSeparator;

  // -----------------------------------------------------------------
  // Drive detection
  // -----------------------------------------------------------------

  /// Lists drives that can receive a backup: removable (flash) and fixed
  /// (external hard disk) drives, excluding the Windows system drive and
  /// the drive that holds the live database itself.
  static Future<List<BackupDrive>> listDrives() async {
    if (!Platform.isWindows) return const [];

    final String systemDrive =
        (Platform.environment['SystemDrive'] ?? 'C:').toUpperCase();
    String dataDrive = '';
    try {
      dataDrive = HiveService.dataDirectory.absolute.path.substring(0, 2).toUpperCase();
    } catch (_) {}

    List<BackupDrive> drives = await _listDrivesViaPowerShell();
    if (drives.isEmpty) drives = _listDrivesByProbing();

    final result = <BackupDrive>[];
    for (final d in drives) {
      final letter = d.letter.toUpperCase();
      if (letter == systemDrive || letter == dataDrive) continue;
      result.add(await _withBackupInfo(d));
    }

    // Drives that already hold a backup first, then flash drives.
    result.sort((a, b) {
      if (a.hasExistingBackup != b.hasExistingBackup) return a.hasExistingBackup ? -1 : 1;
      if (a.isRemovable != b.isRemovable) return a.isRemovable ? -1 : 1;
      return a.letter.compareTo(b.letter);
    });
    return result;
  }

  static Future<List<BackupDrive>> _listDrivesViaPowerShell() async {
    const script =
        r"Get-CimInstance Win32_LogicalDisk | ForEach-Object { '{0}|{1}|{2}|{3}|{4}' -f $_.DeviceID,$_.DriveType,$_.VolumeName,$_.FreeSpace,$_.Size }";
    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        // Default system encoding: PowerShell writes in the OEM/ANSI code
        // page, and a strict UTF-8 decode could throw on Arabic labels.
      ).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) return const [];

      final drives = <BackupDrive>[];
      for (final raw in LineSplitter.split(result.stdout.toString())) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        final parts = line.split('|');
        if (parts.length < 5) continue;
        final id = parts[0].trim(); // "E:"
        final type = int.tryParse(parts[1].trim()) ?? 0;
        if (id.length != 2 || (type != 2 && type != 3)) continue;
        drives.add(BackupDrive(
          root: '$id\\',
          driveType: type,
          volumeLabel: parts[2],
          freeBytes: int.tryParse(parts[3].trim()),
          sizeBytes: int.tryParse(parts[4].trim()),
        ));
      }
      return drives;
    } catch (e) {
      debugPrint('[BackupService] PowerShell drive listing failed: $e');
      return const [];
    }
  }

  /// Fallback when PowerShell is unavailable: probe drive letters.
  static List<BackupDrive> _listDrivesByProbing() {
    final drives = <BackupDrive>[];
    for (final letter in 'DEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      try {
        if (Directory('$letter:\\').existsSync()) {
          drives.add(BackupDrive(root: '$letter:\\', volumeLabel: '', driveType: 0));
        }
      } catch (_) {}
    }
    return drives;
  }

  static Future<BackupDrive> _withBackupInfo(BackupDrive d) async {
    final backupDir = Directory('${d.root}$backupFolderName');
    final legacyDir = Directory('${d.root}$legacyFolderName');
    bool has = false;
    DateTime? last;
    try {
      has = await backupDir.exists() || await legacyDir.exists();
      final manifest = await _readManifest(backupDir);
      last = DateTime.tryParse((manifest['lastBackupAt'] ?? '').toString());
    } catch (_) {}
    return BackupDrive(
      root: d.root,
      volumeLabel: d.volumeLabel,
      driveType: d.driveType,
      freeBytes: d.freeBytes,
      sizeBytes: d.sizeBytes,
      hasExistingBackup: has,
      lastBackupAt: last,
    );
  }

  // -----------------------------------------------------------------
  // Backup
  // -----------------------------------------------------------------

  static Future<BackupReport> backupTo(BackupDrive drive) async {
    // Make sure everything Hive has buffered is on disk first.
    await HiveService.flushAll();

    final Directory source = HiveService.dataDirectory;
    final Directory backupRoot = Directory('${drive.root}$backupFolderName');
    final Directory target = Directory('${backupRoot.path}$_sep$dataSubFolder');
    await target.create(recursive: true);

    final Map<String, dynamic> manifest = await _readManifest(backupRoot);
    final DateTime? previous =
        DateTime.tryParse((manifest['lastBackupAt'] ?? '').toString());
    final Map<String, dynamic> fileStates =
        Map<String, dynamic>.from((manifest['files'] as Map?) ?? const {});

    int appended = 0;
    int copied = 0;
    int unchanged = 0;
    int bytesWritten = 0;
    final errors = <String>[];

    final sourceFiles = (await source.list().toList())
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.hive'))
        .toList();

    for (final srcFile in sourceFiles) {
      final String name = srcFile.path.split(_sep).last;
      final File destFile = File('${target.path}$_sep$name');

      try {
        // Seed from the old flat "SamaBackup" folder once, so data that is
        // already on the drive is reused instead of copied again.
        if (!await destFile.exists()) {
          final legacy = File('${drive.root}$legacyFolderName$_sep$name');
          if (await legacy.exists()) {
            await _safeCopy(legacy, destFile);
          }
        }

        final int srcLen = await srcFile.length();
        final int srcModified = (await srcFile.lastModified()).millisecondsSinceEpoch;
        final Map? lastState = fileStates[name] as Map?;

        if (await destFile.exists()) {
          final int destLen = await destFile.length();

          // Fast path: nothing changed since the last backup.
          if (lastState != null &&
              lastState['size'] == srcLen &&
              lastState['modified'] == srcModified &&
              destLen == srcLen) {
            unchanged++;
            continue;
          }

          final bool isPrefix =
              destLen > 0 && destLen <= srcLen && await _isPrefixOf(destFile, srcFile, destLen);

          if (isPrefix && destLen == srcLen) {
            unchanged++;
          } else if (isPrefix) {
            // Only the records written after the last backup.
            final written = await _appendTail(srcFile, destFile, destLen, srcLen);
            if (await destFile.length() == srcLen) {
              appended++;
              bytesWritten += written;
            } else {
              await _safeCopy(srcFile, destFile);
              copied++;
              bytesWritten += srcLen;
            }
          } else {
            // Hive compacted the file (or the copy differs) - full copy.
            await _safeCopy(srcFile, destFile);
            copied++;
            bytesWritten += srcLen;
          }
        } else {
          await _safeCopy(srcFile, destFile);
          copied++;
          bytesWritten += srcLen;
        }

        fileStates[name] = {'size': srcLen, 'modified': srcModified};
      } catch (e) {
        errors.add('$name: $e');
      }
    }

    final now = DateTime.now();
    final history = List<dynamic>.from((manifest['history'] as List?) ?? const []);
    history.add({
      'at': now.toIso8601String(),
      'appended': appended,
      'copied': copied,
      'unchanged': unchanged,
      'bytes': bytesWritten,
      'errors': errors.length,
    });
    while (history.length > 50) {
      history.removeAt(0);
    }

    // Only move "last backup" forward when every file succeeded.
    final newManifest = <String, dynamic>{
      'app': 'Fikra',
      'lastBackupAt': errors.isEmpty ? now.toIso8601String() : manifest['lastBackupAt'],
      'sourceFolder': source.path,
      'files': fileStates,
      'history': history,
    };
    await _writeManifest(backupRoot, newManifest);
    await _appendLog(backupRoot, now, appended, copied, unchanged, bytesWritten, errors);
    await _writeReadmeOnce(backupRoot);

    return BackupReport(
      backupPath: backupRoot.path,
      finishedAt: now,
      previousBackupAt: previous,
      appendedFiles: appended,
      copiedFiles: copied,
      unchangedFiles: unchanged,
      bytesWritten: bytesWritten,
      errors: errors,
    );
  }

  /// True when the first [length] bytes of [big] equal all of [prefix].
  static Future<bool> _isPrefixOf(File prefix, File big, int length) async {
    final a = await prefix.open();
    final b = await big.open();
    try {
      int remaining = length;
      while (remaining > 0) {
        final int n = remaining < _chunkSize ? remaining : _chunkSize;
        final Uint8List x = await a.read(n);
        final Uint8List y = await b.read(n);
        if (x.length != n || y.length != n) return false;
        for (int i = 0; i < n; i++) {
          if (x[i] != y[i]) return false;
        }
        remaining -= n;
      }
      return true;
    } finally {
      await a.close();
      await b.close();
    }
  }

  /// Appends bytes [from, to) of [src] to the end of [dest].
  static Future<int> _appendTail(File src, File dest, int from, int to) async {
    final reader = await src.open();
    final writer = await dest.open(mode: FileMode.append);
    int written = 0;
    try {
      await reader.setPosition(from);
      int remaining = to - from;
      while (remaining > 0) {
        final int n = remaining < _chunkSize ? remaining : _chunkSize;
        final Uint8List chunk = await reader.read(n);
        if (chunk.isEmpty) break;
        await writer.writeFrom(chunk);
        written += chunk.length;
        remaining -= chunk.length;
      }
      await writer.flush();
    } finally {
      await reader.close();
      await writer.close();
    }
    return written;
  }

  /// Copies [src] over [dest] via a temp file, so an interrupted copy
  /// (drive pulled out) never destroys the previous backup copy.
  static Future<void> _safeCopy(File src, File dest) async {
    final tmp = File('${dest.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
    await src.copy(tmp.path);
    await tmp.rename(dest.path);
  }

  static Future<Map<String, dynamic>> _readManifest(Directory backupRoot) async {
    final file = File('${backupRoot.path}$_sep$manifestName');
    try {
      if (!await file.exists()) return <String, dynamic>{};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (e) {
      // A damaged manifest only disables the fast path; the byte-level
      // prefix check still prevents copying existing data again.
      debugPrint('[BackupService] Manifest unreadable, rebuilding: $e');
      return <String, dynamic>{};
    }
  }

  static Future<void> _writeManifest(Directory backupRoot, Map<String, dynamic> data) async {
    final file = File('${backupRoot.path}$_sep$manifestName');
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
    await tmp.rename(file.path);
  }

  static Future<void> _appendLog(
    Directory backupRoot,
    DateTime at,
    int appended,
    int copied,
    int unchanged,
    int bytes,
    List<String> errors,
  ) async {
    try {
      final log = File('${backupRoot.path}$_sep$logName');
      await log.writeAsString(
        '${at.toIso8601String()}  appended=$appended  copied=$copied  '
        'unchanged=$unchanged  bytes=$bytes  errors=${errors.length}'
        '${errors.isEmpty ? '' : '  [${errors.join('; ')}]'}\r\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
  }

  static Future<void> _writeReadmeOnce(Directory backupRoot) async {
    try {
      final readme = File('${backupRoot.path}${_sep}README.txt');
      if (await readme.exists()) return;
      await readme.writeAsString(
        'نسخة احتياطية لقاعدة بيانات برنامج Fikra\r\n'
        '\r\n'
        'لاسترجاع البيانات:\r\n'
        '1) أغلق البرنامج تماماً.\r\n'
        '2) انسخ كل الملفات الموجودة داخل المجلد HiveData\r\n'
        '3) والصقها داخل مجلد البيانات fikra_data الخاص بالبرنامج (استبدال الملفات).\r\n'
        '4) شغّل البرنامج.\r\n',
        flush: true,
      );
    } catch (_) {}
  }

  /// Human-readable size, e.g. "1.4 MB".
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
