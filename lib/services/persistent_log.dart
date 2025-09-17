import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PersistentLog {
  static File? _file;
  static const _fileName = 'silver_support_logs.txt';
  static const _maxBytes = 1024 * 1024; // 1MB rotate threshold

  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/$_fileName';
      _file = File(path);
      if (!(await _file!.exists())) await _file!.create(recursive: true);
      // rotate if larger than threshold
      final len = await _file!.length();
      if (len > _maxBytes) {
        final backup = File('${dir.path}/silver_support_logs.bak.txt');
        await _file!.copy(backup.path);
        await _file!.writeAsString('');
      }
      await append('PersistentLog initialized at ${DateTime.now().toIso8601String()}');
    } catch (_) {
      // Swallow errors — logging should never crash the app
    }
  }

  static Future<void> append(String message, {String name = 'SilverSupport'}) async {
    try {
      if (_file == null) return;
      final timestamp = DateTime.now().toIso8601String();
      await _file!.writeAsString('[$timestamp] [$name] $message\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }
}
