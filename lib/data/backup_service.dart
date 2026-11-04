// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'shop_database.dart';

/// Portable, offline backup archive. ZIP entries use the widely supported
/// "stored" method; checksums in the manifest detect accidental corruption.
class BackupService {
  static const formatVersion = 1;
  static const maxArchiveBytes = 1024 * 1024 * 1024;
  static const maxEntries = 20000;
  static const maxEntryBytes = 512 * 1024 * 1024;
  static Directory? localRootOverride;

  static Future<Directory> localFolder() async {
    if (localRootOverride != null) return localRootOverride!;
    final root = Platform.environment['LOCALAPPDATA'];
    final base = root == null || root.isEmpty
        ? Directory.systemTemp
        : Directory(root);
    return Directory('${base.path}${Platform.pathSeparator}TailorShop');
  }

  static Future<File> preferencesFile() async {
    final folder = await localFolder();
    await folder.create(recursive: true);
    return File(
      '${folder.path}${Platform.pathSeparator}backup_preferences.json',
    );
  }

  static Future<Map<String, dynamic>> preferences() async {
    final file = await preferencesFile();
    if (!await file.exists()) return {};
    try {
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePreferences(Map<String, dynamic> values) async {
    final file = await preferencesFile();
    final old = await preferences();
    await file.writeAsString(jsonEncode({...old, ...values}), flush: true);
  }

  static Future<File> createBackup(
    ShopDatabase shop,
    String destination,
  ) async {
    final folder = Directory(destination);
    await folder.create(recursive: true);
    final probe = File(
      '${folder.path}${Platform.pathSeparator}.tailor_shop_write_test',
    );
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    final free = await _freeSpace(folder.path);
    if (free != null && free < 32 * 1024 * 1024)
      throw StateError('Not enough free disk space.');

    final work = await Directory.systemTemp.createTemp('tailor_backup_');
    try {
      final snapshot = File(
        '${work.path}${Platform.pathSeparator}database.sqlite',
      );
      await shop.db.execute('VACUUM INTO ?', [snapshot.path]);
      final snapshotDb = await openDatabase(snapshot.path);
      final assetEntries = <String, Uint8List>{};
      final tokensByPath = <String, String>{};
      final missingAssets = <Map<String, Object?>>[];
      var missingAssetCount = 0;
      try {
        final references = await _assetReferences(snapshotDb);
        var assetIndex = 0;
        for (final reference in references) {
          final original = reference.value.trim();
          if (original.isEmpty) continue;
          var token = tokensByPath[original];
          if (token == null && original.startsWith('backup_asset:')) {
            missingAssetCount++;
            missingAssets.add(reference.diagnostic);
            await _writeAssetReference(snapshotDb, reference, '');
            continue;
          }
          if (token == null) {
            final asset = File(original);
            if (!await asset.exists()) {
              missingAssetCount++;
              missingAssets.add(reference.diagnostic);
              await _writeAssetReference(snapshotDb, reference, '');
              continue;
            }
            final beforeStat = await asset.stat();
            if (beforeStat.type != FileSystemEntityType.file ||
                beforeStat.size > maxEntryBytes) {
              throw StateError(
                'A referenced asset is not a supported file or exceeds the size limit.',
              );
            }
            final key =
                '${reference.table}_$assetIndex${_extension(asset.path)}';
            token = 'backup_asset:assets/$key';
            final assetBytes = await asset.readAsBytes();
            final afterStat = await asset.stat();
            if (beforeStat.size != afterStat.size ||
                beforeStat.modified != afterStat.modified ||
                assetBytes.length != afterStat.size) {
              throw StateError(
                'A referenced file changed while the backup was being created. Try again.',
              );
            }
            assetEntries['assets/$key'] = assetBytes;
            tokensByPath[original] = token;
            assetIndex++;
          }
          await _writeAssetReference(snapshotDb, reference, token);
        }
        final snapshotCheck = await snapshotDb.rawQuery(
          'PRAGMA integrity_check',
        );
        if (snapshotCheck.first.values.first != 'ok')
          throw StateError('Database snapshot failed integrity validation.');
        final snapshotForeignKeys = await snapshotDb.rawQuery(
          'PRAGMA foreign_key_check',
        );
        if (snapshotForeignKeys.isNotEmpty)
          throw StateError('Database snapshot has invalid linked records.');
      } finally {
        await snapshotDb.close();
      }

      final entries = <String, Uint8List>{
        'database.sqlite': await snapshot.readAsBytes(),
      };
      entries.addAll(assetEntries);
      final fileManifest = <String, dynamic>{};
      if (entries.length > maxEntries - 1 ||
          entries.values.fold<int>(0, (sum, data) => sum + data.length) >
              maxArchiveBytes) {
        throw StateError('Backup exceeds the allowed archive size.');
      }
      final estimatedSize = entries.values.fold<int>(
        1024 * 1024,
        (sum, data) => sum + data.length,
      );
      if (free != null && free < estimatedSize) {
        throw StateError('Not enough free disk space for this backup.');
      }
      for (final item in entries.entries) {
        fileManifest[item.key] = {
          'size': item.value.length,
          'sha256': sha256.convert(item.value).toString(),
        };
      }
      final manifestDb = await openDatabase(snapshot.path, readOnly: true);
      late int snapshotVersion;
      late String shopName;
      try {
        snapshotVersion = await manifestDb.getVersion();
        shopName = await _settingValue(manifestDb, 'shop_name');
      } finally {
        await manifestDb.close();
      }
      if (snapshotVersion != ShopDatabase.schemaVersion)
        throw StateError('Database snapshot schema is not current.');
      final manifest = <String, dynamic>{
        'format_version': formatVersion,
        'application_version': '1.0.0+1',
        'database_schema_version': snapshotVersion,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'shop_name': shopName,
        'missing_asset_count': missingAssetCount,
        'missing_assets': missingAssets,
        'files': fileManifest,
      };
      entries['manifest.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );
      final bytes = await Isolate.run(() => _ZipStored.write(entries));
      if (bytes.length > maxArchiveBytes)
        throw StateError('Backup exceeds the 1 GB size limit.');
      final now = DateTime.now();
      final name =
          'tailor_shop_backup_${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}.zip';
      final finalFile = File('${folder.path}${Platform.pathSeparator}$name');
      final tempFile = File(
        '${folder.path}${Platform.pathSeparator}.$name.tmp',
      );
      try {
        await tempFile.writeAsBytes(bytes, flush: true);
        await _validatedArchive(tempFile.path);
        await tempFile.rename(finalFile.path);
      } finally {
        if (await tempFile.exists()) await tempFile.delete();
      }
      try {
        await savePreferences({
          'folder': folder.path,
          'last_file': finalFile.path,
          'last_at': manifest['created_at'],
        });
      } catch (_) {
        // The portable archive is already complete; local history is optional.
      }
      return finalFile;
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  static Future<Map<String, dynamic>> inspect(String path) async {
    final archive = await _validatedArchive(path);
    return archive.preview;
  }

  static Future<_ValidatedArchive> _validatedArchive(String path) async {
    final file = File(path);
    if (!await file.exists()) throw StateError('Backup file was not found.');
    if (await file.length() > maxArchiveBytes)
      throw StateError('Backup archive exceeds the size limit.');
    final entries = _ZipStored.read(await file.readAsBytes());
    if (entries.length > maxEntries ||
        !entries.containsKey('manifest.json') ||
        !entries.containsKey('database.sqlite'))
      throw StateError('Backup archive is incomplete.');
    final manifest = jsonDecode(
      utf8.decode(entries['manifest.json']!),
    ) as Map<String, dynamic>;
    if (manifest['format_version'] != formatVersion)
      throw StateError('This backup format is not supported.');
    final declaredSchema = manifest['database_schema_version'];
    if (declaredSchema is! int ||
        declaredSchema < 1 ||
        declaredSchema > ShopDatabase.schemaVersion)
      throw StateError('Backup database schema is not supported.');
    if (manifest['application_version'] is! String ||
        (manifest['application_version'] as String).isEmpty ||
        DateTime.tryParse('${manifest['created_at']}') == null ||
        manifest['shop_name'] is! String ||
        manifest['missing_asset_count'] is! int ||
        (manifest['missing_asset_count'] as int) < 0) {
      throw StateError('Backup manifest is incomplete.');
    }
    final expected = manifest['files'];
    if (expected is! Map<String, dynamic>)
      throw StateError('Backup manifest is invalid.');
    var total = 0;
    for (final name in entries.keys) {
      if (name == 'manifest.json') continue;
      if (name != 'database.sqlite' &&
          (!name.startsWith('assets/') ||
              name.substring('assets/'.length).isEmpty ||
              name.substring('assets/'.length).contains('/') ||
              name.substring('assets/'.length).contains('\\')))
        throw StateError('Backup contains an unsupported file path.');
      if (!expected.containsKey(name))
        throw StateError('Archive contains an unexpected file.');
      final bytes = entries[name]!;
      total += bytes.length;
      if (bytes.length > maxEntryBytes || total > maxArchiveBytes)
        throw StateError('Backup expands beyond the allowed size.');
      final info = expected[name];
      if (info is! Map ||
          info['size'] != bytes.length ||
          info['sha256'] != sha256.convert(bytes).toString())
        throw StateError('Backup checksum validation failed.');
    }
    if (expected.length != entries.length - 1)
      throw StateError('Backup archive is incomplete.');
    final work = await Directory.systemTemp.createTemp('tailor_preview_');
    try {
      final dbFile = File(
        '${work.path}${Platform.pathSeparator}database.sqlite',
      );
      await dbFile.writeAsBytes(entries['database.sqlite']!);
      final db = await openDatabase(dbFile.path, readOnly: true);
      try {
        final version = await db.getVersion();
        if (version < 1 || version > ShopDatabase.schemaVersion)
          throw StateError(
            'Database schema $version is not supported by this app.',
          );
        final integrity = await db.rawQuery('PRAGMA integrity_check');
        if (integrity.first.values.first != 'ok')
          throw StateError('Backup database failed integrity validation.');
        final fk = await db.rawQuery('PRAGMA foreign_key_check');
        if (fk.isNotEmpty)
          throw StateError('Backup database has invalid linked records.');
        for (final reference in await _assetReferences(db)) {
          if (!reference.value.startsWith('backup_asset:')) continue;
          final key = reference.value.substring('backup_asset:'.length);
          if (!key.startsWith('assets/') ||
              key.substring('assets/'.length).isEmpty ||
              key.substring('assets/'.length).contains('/') ||
              !entries.containsKey(key))
            throw StateError('Backup contains a missing or unsafe asset.');
        }
        final preview = <String, dynamic>{
          ...manifest,
          'attachment_count': entries.keys
              .where((e) => e.startsWith('assets/'))
              .length,
          'database_version': version,
        };
        return _ValidatedArchive(
          entries: entries,
          manifest: manifest,
          databaseVersion: version,
          preview: preview,
        );
      } finally {
        await db.close();
      }
    } finally {
      await work.delete(recursive: true);
    }
  }

  static Future<void> restore(ShopDatabase shop, String path) async {
    // Read and validate the archive exactly once so a file cannot be swapped
    // between preview and restore.
    final validated = await _validatedArchive(path);
    final archive = validated.entries;
    final livePath = await shop.databasePath();
    if (livePath.isEmpty)
      throw StateError('The current database cannot be safely replaced.');
    final work = await Directory.systemTemp.createTemp('tailor_restore_');
    final staging = File(
      '${work.path}${Platform.pathSeparator}restored.sqlite',
    );
    final rollback = File('$livePath.rollback');
    final oldWal = File('$livePath-wal');
    final oldShm = File('$livePath-shm');
    final safety = File('${work.path}${Platform.pathSeparator}safety.sqlite');
    String? newAssetsPath;
    Database? restoredDatabase;
    var oldDatabaseClosed = false;
    var replacementStarted = false;
    var committed = false;
    try {
      await staging.writeAsBytes(archive['database.sqlite']!);
      final staged = await ShopDatabase.openAt(staging.path);
      final assetDir = Directory(
        '${(await localFolder()).path}${Platform.pathSeparator}restored_assets_${DateTime.now().microsecondsSinceEpoch}',
      );
      await assetDir.create(recursive: true);
      newAssetsPath = assetDir.path;
      try {
        for (final entry in archive.entries.where(
          (e) => e.key.startsWith('assets/'),
        )) {
          final leaf = entry.key.substring('assets/'.length);
          await File('${assetDir.path}${Platform.pathSeparator}$leaf')
              .writeAsBytes(entry.value, flush: true);
        }
        for (final reference in await _assetReferences(staged.db)) {
          final value = reference.value;
          if (!value.startsWith('backup_asset:assets/')) continue;
          final leaf = value.substring('backup_asset:assets/'.length);
          await _writeAssetReference(
            staged.db,
            reference,
            '${assetDir.path}${Platform.pathSeparator}$leaf',
          );
        }
        await _validateDatabase(staged.db, 'Staged restored database');
        final checkpoint = await staged.db.rawQuery(
          'PRAGMA wal_checkpoint(TRUNCATE)',
        );
        if (checkpoint.isNotEmpty &&
            (checkpoint.first['busy'] as num? ?? 0) != 0) {
          throw StateError('Staged database could not be finalized safely.');
        }
      } finally {
        await staged.db.close();
      }
      for (final suffix in ['-wal', '-shm']) {
        final sidecar = File('${staging.path}$suffix');
        if (suffix == '-wal' &&
            await sidecar.exists() &&
            await sidecar.length() > 32) {
          throw StateError('Staged database still has uncheckpointed writes.');
        }
        if (await sidecar.exists()) await sidecar.delete();
      }

      // Keep a validated, WAL-safe copy until the replacement is fully open.
      await shop.db.execute('VACUUM INTO ?', [safety.path]);
      final safetyDb = await openDatabase(safety.path, readOnly: true);
      try {
        await _validateDatabase(safetyDb, 'Safety copy');
      } finally {
        await safetyDb.close();
      }
      await shop.db.close();
      oldDatabaseClosed = true;
      if (await oldWal.exists()) await oldWal.delete();
      if (await oldShm.exists()) await oldShm.delete();
      if (await rollback.exists()) await rollback.delete();
      await File(livePath).rename(rollback.path);
      replacementStarted = true;
      await staging.rename(livePath);
      restoredDatabase = (await ShopDatabase.openAt(
        livePath,
        recoverInterruptedRestore: false,
      )).db;
      await _validateDatabase(restoredDatabase, 'Restored database');
      await restoredDatabase.close();
      restoredDatabase = null;
      // Keep safety.sqlite until after the validated file is live again.
      if (await rollback.exists()) await rollback.delete();
      shop.db = (await ShopDatabase.openAt(
        livePath,
        recoverInterruptedRestore: false,
      )).db;
      committed = true;
      try {
        await savePreferences({
          'last_restored_at': validated.preview['created_at'],
          'last_restored_file': path,
        });
      } catch (_) {
        // Machine-local history must not invalidate restored data.
      }
    } catch (_) {
      if (!committed && oldDatabaseClosed) {
        try {
          await restoredDatabase?.close();
        } catch (_) {}
        if (replacementStarted) {
          for (final sidecar in [oldWal, oldShm]) {
            if (await sidecar.exists()) await sidecar.delete();
          }
          final current = File(livePath);
          if (await current.exists()) await current.delete();
          if (await rollback.exists()) {
            try {
              await rollback.rename(livePath);
            } catch (_) {
              if (!await safety.exists()) rethrow;
              await safety.copy(livePath);
            }
          } else if (await safety.exists()) {
            await safety.copy(livePath);
          } else {
            throw StateError(
              'Restore failed and no validated recovery copy is available.',
            );
          }
        }
        shop.db = (await ShopDatabase.openAt(
          livePath,
          recoverInterruptedRestore: false,
        )).db;
      }
      rethrow;
    } finally {
      if (!committed && newAssetsPath != null) {
        final folder = Directory(newAssetsPath);
        if (await folder.exists()) {
          try {
            await folder.delete(recursive: true);
          } catch (_) {}
        }
      }
      if (committed && await safety.exists()) {
        try {
          await safety.delete();
        } catch (_) {}
      }
      if (await work.exists()) {
        try {
          await work.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  static Future<String> _settingValue(DatabaseExecutor db, String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key=?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? '' : (rows.first['value']?.toString() ?? '');
  }

  /// Finds file-backed values across the business schema. Receipt images are
  /// stored as SQLite BLOBs and need no path handling here.
  static Future<List<_AssetReference>> _assetReferences(
    DatabaseExecutor db,
  ) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final result = <_AssetReference>[];
    for (final tableRow in tables) {
      final table = tableRow['name']?.toString() ?? '';
      if (table.isEmpty) continue;
      final columns = await db.rawQuery(
        'PRAGMA table_info("${_quote(table)}")',
      );
      if (table == 'settings') {
        final hasKey = columns.any((row) => row['name'] == 'key');
        final hasValue = columns.any((row) => row['name'] == 'value');
        if (!hasKey || !hasValue) continue;
        final rows = await db.rawQuery(
          'SELECT rowid AS "__backup_rowid", "key", "value" FROM "${_quote(table)}"',
        );
        for (final row in rows) {
          final key = row['key']?.toString() ?? '';
          final value = row['value'];
          if (!_isPathField(key) || value is! String || value.isEmpty) continue;
          result.add(
            _AssetReference(
              table: table,
              column: 'value',
              rowId: row['__backup_rowid'],
              value: value,
              notNull: true,
              settingKey: key,
            ),
          );
        }
        continue;
      }
      final pathColumns = columns.where((row) {
        final name = row['name']?.toString() ?? '';
        return _isPathField(name);
      });
      for (final info in pathColumns) {
        final column = info['name'].toString();
        final rows = await db.rawQuery(
          'SELECT rowid AS "__backup_rowid", "${_quote(column)}" FROM "${_quote(table)}"',
        );
        for (final row in rows) {
          final value = row[column];
          if (value is! String || value.isEmpty) continue;
          result.add(
            _AssetReference(
              table: table,
              column: column,
              rowId: row['__backup_rowid'],
              value: value,
              notNull: (info['notnull'] as num? ?? 0) != 0,
            ),
          );
        }
      }
    }
    return result;
  }

  static bool _isPathField(String value) {
    final normalized = value.toLowerCase();
    return normalized == 'path' || normalized.endsWith('_path');
  }

  static String _quote(String value) => value.replaceAll('"', '""');

  static Future<void> _writeAssetReference(
    DatabaseExecutor db,
    _AssetReference reference,
    String value,
  ) async {
    await db.update(
      reference.table,
      {reference.column: value.isEmpty && !reference.notNull ? null : value},
      where: reference.settingKey == null ? 'rowid=?' : 'key=?',
      whereArgs: [reference.settingKey ?? reference.rowId],
    );
  }

  static Future<void> _validateDatabase(
    DatabaseExecutor db,
    String label,
  ) async {
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    if (integrity.isEmpty || integrity.first.values.first != 'ok')
      throw StateError('$label failed integrity validation.');
    final foreignKeys = await db.rawQuery('PRAGMA foreign_key_check');
    if (foreignKeys.isNotEmpty)
      throw StateError('$label has invalid linked records.');
  }

  static String _extension(String path) {
    final i = path.lastIndexOf('.');
    return i < 0
        ? '.bin'
        : path.substring(i).replaceAll(RegExp(r'[^.A-Za-z0-9]'), '');
  }

  static Future<int?> _freeSpace(String path) async {
    try {
      if (!Platform.isWindows) return null;
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-Command',
        "(Get-PSDrive -Name '${path.substring(0, 1)}').Free",
      ]);
      return int.tryParse('${result.stdout}'.trim());
    } catch (_) {
      return null;
    }
  }
}

class _AssetReference {
  const _AssetReference({
    required this.table,
    required this.column,
    required this.rowId,
    required this.value,
    required this.notNull,
    this.settingKey,
  });

  final String table;
  final String column;
  final Object? rowId;
  final String value;
  final bool notNull;
  final String? settingKey;

  Map<String, Object?> get diagnostic => {
    'table': table,
    'column': settingKey ?? column,
    if (settingKey != null) 'key': settingKey,
  };
}

class _ValidatedArchive {
  const _ValidatedArchive({
    required this.entries,
    required this.manifest,
    required this.databaseVersion,
    required this.preview,
  });

  final Map<String, Uint8List> entries;
  final Map<String, dynamic> manifest;
  final int databaseVersion;
  final Map<String, dynamic> preview;
}

class _ZipStored {
  static Uint8List write(Map<String, Uint8List> files) {
    final out = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    var offset = 0;
    final now = DateTime.now();
    final dosTime = (now.hour << 11) | (now.minute << 5) | (now.second ~/ 2);
    final dosDate =
        ((max(1980, now.year) - 1980) << 9) | (now.month << 5) | now.day;
    for (final entry in files.entries) {
      final name = utf8.encode(entry.key);
      final data = entry.value;
      final crc = _crc32(data);
      final local = ByteData(30);
      local.setUint32(0, 0x04034b50, Endian.little);
      local.setUint16(4, 20, Endian.little);
      local.setUint16(6, 0x0800, Endian.little);
      local.setUint16(10, dosTime, Endian.little);
      local.setUint16(12, dosDate, Endian.little);
      local.setUint32(14, crc, Endian.little);
      local.setUint32(18, data.length, Endian.little);
      local.setUint32(22, data.length, Endian.little);
      local.setUint16(26, name.length, Endian.little);
      out.add(local.buffer.asUint8List());
      out.add(name);
      out.add(data);
      final c = ByteData(46);
      c.setUint32(0, 0x02014b50, Endian.little);
      c.setUint16(4, 20, Endian.little);
      c.setUint16(6, 20, Endian.little);
      c.setUint16(8, 0x0800, Endian.little);
      c.setUint16(12, dosTime, Endian.little);
      c.setUint16(14, dosDate, Endian.little);
      c.setUint32(16, crc, Endian.little);
      c.setUint32(20, data.length, Endian.little);
      c.setUint32(24, data.length, Endian.little);
      c.setUint16(28, name.length, Endian.little);
      c.setUint32(42, offset, Endian.little);
      central.add(c.buffer.asUint8List());
      central.add(name);
      offset += 30 + name.length + data.length;
    }
    final centralBytes = central.takeBytes();
    out.add(centralBytes);
    final end = ByteData(22);
    end.setUint32(0, 0x06054b50, Endian.little);
    end.setUint16(8, files.length, Endian.little);
    end.setUint16(10, files.length, Endian.little);
    end.setUint32(12, centralBytes.length, Endian.little);
    end.setUint32(16, offset, Endian.little);
    out.add(end.buffer.asUint8List());
    return out.takeBytes();
  }

  static Map<String, Uint8List> read(Uint8List bytes) {
    if (bytes.length > BackupService.maxArchiveBytes)
      throw StateError('Backup archive exceeds the size limit.');
    final data = ByteData.sublistView(bytes);
    var end = -1;
    final start = max(0, bytes.length - 65557);
    for (var i = bytes.length - 22; i >= start; i--) {
      if (data.getUint32(i, Endian.little) == 0x06054b50) {
        end = i;
        break;
      }
    }
    if (end < 0) throw StateError('Backup ZIP directory is missing.');
    final disk = data.getUint16(end + 4, Endian.little);
    final entriesOnDisk = data.getUint16(end + 8, Endian.little);
    final count = data.getUint16(end + 10, Endian.little);
    final dirSize = data.getUint32(end + 12, Endian.little);
    final centralStart = data.getUint32(end + 16, Endian.little);
    var pos = centralStart;
    if (disk != 0 ||
        entriesOnDisk != count ||
        count > BackupService.maxEntries ||
        centralStart + dirSize != end)
      throw StateError('Backup ZIP directory is invalid.');
    final result = <String, Uint8List>{};
    final localRanges = <(int, int)>[];
    for (var n = 0; n < count; n++) {
      if (pos + 46 > bytes.length ||
          data.getUint32(pos, Endian.little) != 0x02014b50)
        throw StateError('Backup ZIP entry is invalid.');
      final method = data.getUint16(pos + 10, Endian.little),
          flags = data.getUint16(pos + 8, Endian.little),
          crc = data.getUint32(pos + 16, Endian.little),
          compressed = data.getUint32(pos + 20, Endian.little),
          size = data.getUint32(pos + 24, Endian.little),
          nameLen = data.getUint16(pos + 28, Endian.little),
          extra = data.getUint16(pos + 30, Endian.little),
          comment = data.getUint16(pos + 32, Endian.little),
          disk = data.getUint16(pos + 34, Endian.little),
          external = data.getUint32(pos + 38, Endian.little),
          local = data.getUint32(pos + 42, Endian.little);
      if (method != 0 ||
          flags & ~0x0800 != 0 ||
          disk != 0 ||
          compressed != size ||
          size > BackupService.maxEntryBytes ||
          size == 0xffffffff ||
          pos + 46 + nameLen + extra + comment > bytes.length)
        throw StateError('Unsupported or oversized ZIP entry.');
      final name = utf8.decode(bytes.sublist(pos + 46, pos + 46 + nameLen));
      if (name.startsWith('/') ||
          name.contains('\\') ||
          name.contains(':') ||
          name.split('/').any((p) => p == '..' || p == '.') ||
          ((external >> 16) & 0xF000) == 0xA000 ||
          result.containsKey(name))
        throw StateError('Unsafe path or link in backup archive.');
      if (local + 30 > bytes.length ||
          data.getUint32(local, Endian.little) != 0x04034b50)
        throw StateError('Backup ZIP payload is invalid.');
      final ln = data.getUint16(local + 26, Endian.little),
          le = data.getUint16(local + 28, Endian.little),
          payload = local + 30 + ln + le;
      final localFlags = data.getUint16(local + 6, Endian.little);
      final localMethod = data.getUint16(local + 8, Endian.little);
      final localCrc = data.getUint32(local + 14, Endian.little);
      final localCompressed = data.getUint32(local + 18, Endian.little);
      final localSize = data.getUint32(local + 22, Endian.little);
      if (local + 30 + ln + le > centralStart ||
          localFlags != flags ||
          localMethod != method ||
          localCrc != crc ||
          localCompressed != compressed ||
          localSize != size ||
          ln != nameLen ||
          utf8.decode(bytes.sublist(local + 30, local + 30 + ln)) != name)
        throw StateError('Backup ZIP headers do not match.');
      if (payload + size > centralStart ||
          localRanges.any(
            (range) => local < range.$2 && range.$1 < payload + size,
          ))
        throw StateError('Backup ZIP entries overlap or are out of bounds.');
      localRanges.add((local, payload + size));
      final payloadBytes = Uint8List.fromList(
        bytes.sublist(payload, payload + size),
      );
      if (_crc32(payloadBytes) != crc)
        throw StateError('Backup ZIP checksum validation failed.');
      result[name] = payloadBytes;
      pos += 46 + nameLen + extra + comment;
    }
    if (pos != centralStart + dirSize)
      throw StateError('Backup ZIP directory length does not match.');
    return result;
  }
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++)
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
