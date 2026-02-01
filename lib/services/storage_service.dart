import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._privateConstructor();
  static final StorageService instance = StorageService._privateConstructor();

  String? _dataPath;

  String get _directoryPath {
    if (kIsWeb) return '';
    if (_dataPath != null) return _dataPath!;
    final executableFile = File(Platform.resolvedExecutable);
    final dir = executableFile.parent;
    _dataPath = '${dir.path}${Platform.pathSeparator}data';
    return _dataPath!;
  }

  Future<void> _ensureDirectoryExists() async {
    if (kIsWeb) return;
    final dir = Directory(_directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  Future<void> save(String filename, Map<String, dynamic> data) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(filename, jsonEncode(data));
        return;
      }
      
      await _ensureDirectoryExists();
      final file = File('$_directoryPath${Platform.pathSeparator}$filename.json');
      final jsonString = jsonEncode(data);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('Error saving $filename: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> load(String filename) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString(filename);
        if (jsonString == null) return null;
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }

      final file = File('$_directoryPath${Platform.pathSeparator}$filename.json');
      if (!await file.exists()) {
        return null;
      }
      final jsonString = await file.readAsString();
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('Error loading $filename: $e');
      return null;
    }
  }


  // --- BACKUP & RESTORE ---

  String get _backupPath => '$_directoryPath${Platform.pathSeparator}backup';

  Future<void> createBackup() async {
    if (kIsWeb) return; // Not supported on Web yet

    await _ensureDirectoryExists();
    final backupDir = Directory(_backupPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final files = ['transactions', 'settings', 'budget']; 

    for (var name in files) {
      final sourceFile = File('$_directoryPath${Platform.pathSeparator}$name.json');
      if (await sourceFile.exists()) {
        await sourceFile.copy('${backupDir.path}${Platform.pathSeparator}$name.json');
      }
    }
  }

  Future<void> restoreBackup() async {
    if (kIsWeb) return; // Not supported on Web yet
    
    await _ensureDirectoryExists(); 
    final backupDir = Directory(_backupPath);
    if (!await backupDir.exists()) return;

    final files = ['transactions', 'settings', 'budget'];

    for (var name in files) {
      final backupFile = File('${backupDir.path}${Platform.pathSeparator}$name.json');
      if (await backupFile.exists()) {
        await backupFile.copy('$_directoryPath${Platform.pathSeparator}$name.json');
      }
    }
  }

  Future<DateTime?> getLastBackupDate() async {
    if (kIsWeb) return null; // Not supported on Web yet
    
    final file = File('${_backupPath}${Platform.pathSeparator}transactions.json');
    if (await file.exists()) {
      return file.lastModified();
    }
    return null;
  }
}
