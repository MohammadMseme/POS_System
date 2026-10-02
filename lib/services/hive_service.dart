import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../models/supplier.dart';
import '../models/supplier_entry.dart';
import '../models/debt.dart';
import '../models/note.dart';
import '../models/worker.dart';
import '../models/expense.dart';

class HiveService {
  /// Names of boxes that failed to open normally during this run and had
  /// to be quarantined (their original files were moved, NOT deleted, to
  /// `hive_quarantine/` inside the dedicated data folder). The app's UI
  /// layer should check this after startup and tell the user their data
  /// for these boxes needs manual recovery, instead of the previous
  /// behavior of silently wiping the box with no trace.
  static final List<String> recoveredBoxWarnings = [];

  /// NEW: name of the single, dedicated folder that holds ALL Hive files.
  static const String dataFolderName = 'fikra_data';

  /// Every box the app uses (also used by the backup service).
  static const List<String> boxNames = [
    'products',
    'sales',
    'suppliers',
    'debts',
    'notes',
    'workers',
    'expenses',
    'settings',
  ];

  static Directory? _dataDirectory;

  /// The folder holding all Hive files. Valid after [init].
  static Directory get dataDirectory {
    final dir = _dataDirectory;
    if (dir == null) {
      throw StateError('HiveService.init() must be called first');
    }
    return dir;
  }

  static Future<void> init() async {
    // CHANGED: Hive.initFlutter() stored every box directly in the
    // Windows "Documents" folder, mixed with the user's own files. All
    // Hive files now live in ONE dedicated folder (see
    // _resolveDataDirectory), and data from the old location is copied
    // over automatically on first start.
    final dataDir = await _resolveDataDirectory();
    _dataDirectory = dataDir;
    await _migrateFromDocumentsFolder(dataDir);
    Hive.init(dataDir.path);
    debugPrint('[HiveService] Data folder: ${dataDir.path}');

    // تسجيل Adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SaleItemAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SaleAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SupplierPaymentAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(SupplierAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(DebtAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(NoteAdapter());
    // enum adapter backing Sale.source (typeId 7 - does not collide with
    // any existing model typeId 0-6).
    if (!Hive.isAdapterRegistered(7)) Hive.registerAdapter(SaleSourceAdapter());
    // Salaries & Expenses models (typeIds 8-10).
    if (!Hive.isAdapterRegistered(8)) Hive.registerAdapter(WorkerPaymentAdapter());
    if (!Hive.isAdapterRegistered(9)) Hive.registerAdapter(WorkerAdapter());
    if (!Hive.isAdapterRegistered(10)) Hive.registerAdapter(ExpenseAdapter());
    // NEW: supplier order/history models (typeIds 11-12 - do not
    // collide with anything above).
    if (!Hive.isAdapterRegistered(11)) Hive.registerAdapter(SupplierOrderItemAdapter());
    if (!Hive.isAdapterRegistered(12)) Hive.registerAdapter(SupplierEntryAdapter());

    // فتح الصناديق مع المعالجة الآمنة
    await _openBoxSafely<Product>('products');
    await _openBoxSafely<Sale>('sales');
    await _openBoxSafely<Supplier>('suppliers');
    await _openBoxSafely<Debt>('debts');
    await _openBoxSafely<Note>('notes');
    // Salaries & Expenses boxes. Same crash-safe open path as every
    // other box, so a corrupted file here is quarantined - never
    // deleted - exactly like the rest of the app's data.
    await _openBoxSafely<Worker>('workers');
    await _openBoxSafely<Expense>('expenses');

    // NEW: 'settings' box backs AuthProvider (the app password) and any
    // future local app preferences. It stores plain Strings, so no
    // custom Hive TypeAdapter/typeId is required - String is one of the
    // primitive types Hive supports natively. Kept in the exact same
    // safe-open path as every other box, so a corrupted settings file is
    // quarantined (never deleted) just like the rest.
    await _openBoxSafely<String>('settings');

    // NEW: give debts written by older versions the capital-recovery
    // counters used by the credit-sale logic, before any screen reads them.
    await _migrateDebts();
  }

  /// Picks the dedicated data folder, in this order:
  ///  1. Running from a Flutter project build (debug or release, i.e. the
  ///     exe lives under `<project>\build\windows\...`):
  ///     `<project>\fikra_data` - directly inside the project folder, and
  ///     safe from `flutter clean` (which deletes `build\`).
  ///  2. Installed / copied app: `<folder of the .exe>\fikra_data`.
  ///  3. Fallback when that folder is not writable (e.g. Program Files):
  ///     `<AppData support folder>\fikra_data`.
  static Future<Directory> _resolveDataDirectory() async {
    final sep = Platform.pathSeparator;
    final candidates = <String>[];

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final marker = '${sep}build$sep';
      final lower = exeDir.toLowerCase();
      final buildIndex = lower.lastIndexOf(marker);
      if (buildIndex > 0 &&
          (lower.contains('${sep}build${sep}windows$sep') ||
              lower.contains('${sep}build${sep}linux$sep') ||
              lower.contains('${sep}build${sep}macos$sep'))) {
        candidates.add('${exeDir.substring(0, buildIndex)}$sep$dataFolderName');
      }
      candidates.add('$exeDir$sep$dataFolderName');
    } catch (e) {
      debugPrint('[HiveService] Could not resolve executable folder: $e');
    }

    try {
      final support = await getApplicationSupportDirectory();
      candidates.add('${support.path}$sep$dataFolderName');
    } catch (e) {
      debugPrint('[HiveService] Could not resolve support folder: $e');
    }

    for (final path in candidates) {
      final dir = Directory(path);
      if (await _isWritable(dir)) return dir;
    }
    throw FileSystemException('No writable folder found for the database', candidates.join(' | '));
  }

  static Future<bool> _isWritable(Directory dir) async {
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
      final probe = File('${dir.path}${Platform.pathSeparator}.write_test');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One-time copy of the existing database from the old location (the
  /// Documents folder used by Hive.initFlutter) into [dataDir]. The old
  /// files are COPIED, never moved or deleted, so they stay as a safety
  /// copy. A marker file makes sure this only ever runs once.
  static Future<void> _migrateFromDocumentsFolder(Directory dataDir) async {
    final sep = Platform.pathSeparator;
    final marker = File('${dataDir.path}$sep.migrated_from_documents');
    if (await marker.exists()) return;

    try {
      final oldDir = await getApplicationDocumentsDirectory();
      if (oldDir.absolute.path.toLowerCase() == dataDir.absolute.path.toLowerCase()) {
        await marker.writeAsString(DateTime.now().toIso8601String());
        return;
      }
      int copied = 0;
      for (final name in boxNames) {
        final source = File('${oldDir.path}$sep$name.hive');
        final target = File('${dataDir.path}$sep$name.hive');
        // Never overwrite data that already exists in the new folder.
        if (await source.exists() && !await target.exists()) {
          await source.copy(target.path);
          copied++;
        }
      }
      await marker.writeAsString(
        'Migrated $copied box file(s) from ${oldDir.path} on ${DateTime.now().toIso8601String()}',
      );
      if (copied > 0) {
        debugPrint('[HiveService] Copied $copied box file(s) from ${oldDir.path}');
      }
    } catch (e, stack) {
      // No marker on failure -> retried on the next start.
      debugPrint('[HiveService] Migration from Documents failed: $e');
      debugPrint('$stack');
    }
  }

  /// Writes any buffered changes of every open box to disk. Called right
  /// before a backup so the copied files are complete.
  static Future<void> flushAll() async {
    Future<void> flush<T>(String name) async {
      if (Hive.isBoxOpen(name)) await Hive.box<T>(name).flush();
    }

    await flush<Product>('products');
    await flush<Sale>('sales');
    await flush<Supplier>('suppliers');
    await flush<Debt>('debts');
    await flush<Note>('notes');
    await flush<Worker>('workers');
    await flush<Expense>('expenses');
    await flush<String>('settings');
  }

  /// Non-destructive, idempotent upgrade of old Debt records (see
  /// Debt.ensureTracking). A failure here never blocks app start-up.
  static Future<void> _migrateDebts() async {
    try {
      final box = Hive.box<Debt>('debts');
      for (final debt in box.values.toList()) {
        if (debt.ensureTracking()) {
          await debt.save();
        }
      }
    } catch (e, stack) {
      debugPrint('[HiveService] Debt migration skipped: $e');
      debugPrint('$stack');
    }
  }

  /// Opens a box, and if that fails, NEVER deletes the underlying data.
  /// Instead it:
  ///   1. Logs the failure.
  ///   2. Closes any partially-open handle.
  ///   3. Moves (not deletes) the box's on-disk files into a timestamped
  ///      quarantine folder, so the original bytes are always recoverable.
  ///   4. Opens a fresh, empty box under the original name so the app can
  ///      keep functioning.
  ///   5. Records the box name in [recoveredBoxWarnings] so the UI can
  ///      surface an explicit notice to the user after startup.
  static Future<void> _openBoxSafely<T>(String boxName) async {
    try {
      await Hive.openBox<T>(boxName);
      return; // Happy path: nothing else to do.
    } catch (e, stack) {
      debugPrint('[HiveService] Failed to open box "$boxName": $e');
      debugPrint('$stack');
    }

    // The box could not be opened normally. Make sure we don't hold a
    // half-open handle before we touch the files on disk.
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<T>(boxName).close();
      }
    } catch (e) {
      debugPrint('[HiveService] Could not cleanly close box "$boxName" before quarantine: $e');
    }

    try {
      await _quarantineBoxFiles(boxName);
    } catch (e, stack) {
      // If we can't even safely move the files aside, we deliberately do
      // NOT fall back to deleting them. Surface the failure instead of
      // risking destroying the only copy of the user's data.
      debugPrint('[HiveService] Failed to quarantine box "$boxName": $e');
      debugPrint('$stack');
      rethrow;
    }

    // The corrupted/locked files are now safely out of the way (renamed
    // into hive_quarantine/, never deleted). It's safe to start a fresh,
    // empty box under the original name so the app remains usable.
    await Hive.openBox<T>(boxName);
    recoveredBoxWarnings.add(boxName);
    debugPrint(
      '[HiveService] Box "$boxName" could not be opened; the original files '
      'were preserved under hive_quarantine/ and a new empty box was created. '
      'Manual data recovery may be needed.',
    );
  }

  /// Moves (copies then deletes the source, i.e. an effective "move") the
  /// on-disk files for [boxName] into `<app documents>/hive_quarantine/`,
  /// prefixed with a timestamp so repeated failures never overwrite each
  /// other. The files are never permanently discarded by this method.
  static Future<void> _quarantineBoxFiles(String boxName) async {
    // CHANGED: quarantine lives inside the dedicated data folder now.
    final appDir = dataDirectory;
    final quarantineDir = Directory(
      '${appDir.path}${Platform.pathSeparator}hive_quarantine',
    );
    if (!quarantineDir.existsSync()) {
      quarantineDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Hive's default file storage engine writes "<name>.hive" and
    // "<name>.lock" next to the app's documents directory.
    final candidateFileNames = ['$boxName.hive', '$boxName.lock'];

    for (final fileName in candidateFileNames) {
      final source = File('${appDir.path}${Platform.pathSeparator}$fileName');
      if (!source.existsSync()) continue;

      final destination = File(
        '${quarantineDir.path}${Platform.pathSeparator}${timestamp}_$fileName',
      );

      // Copy first, then only remove the original once the copy is
      // confirmed on disk - this way a mid-operation crash never leaves
      // us with zero copies of the data.
      await source.copy(destination.path);
      if (destination.existsSync()) {
        await source.delete();
      }
    }
  }
}
