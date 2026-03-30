import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Desktop (Windows/Linux/macOS) — FFI factory 사용
void initDatabaseFactoryImpl() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
