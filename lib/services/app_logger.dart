import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Lightweight logger wrapper. Only emits in debug builds.
///
/// Usage: `AppLogger.log('Family').info('Created family $id');`
class AppLogger {
  static bool _initialized = false;

  static Logger log(String name) {
    if (!_initialized) {
      _initialized = true;
      Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;
      Logger.root.onRecord.listen((record) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[${record.level.name}] ${record.loggerName}: ${record.message}'
              '${record.error != null ? ' | ${record.error}' : ''}');
        }
      });
    }
    return Logger(name);
  }
}
