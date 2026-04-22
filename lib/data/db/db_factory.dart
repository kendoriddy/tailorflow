import 'package:flutter/foundation.dart' show kIsWeb;

import 'db_factory_web.dart' if (dart.library.io) 'db_factory_io.dart';

/// Configure sqflite so `openDatabase()` works on the current platform.
void configureSqfliteForCurrentPlatform() {
  if (kIsWeb) {
    configureSqfliteWeb();
  } else {
    configureSqfliteIo();
  }
}
