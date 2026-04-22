import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void configureSqfliteWeb() {
  // Switch sqflite to a web-capable implementation (IndexedDB-backed).
  databaseFactory = databaseFactoryFfiWeb;
}

void configureSqfliteIo() {
  // No-op on web.
}
