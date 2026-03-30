import 'database_init_stub.dart'
    if (dart.library.ffi) 'database_init_ffi.dart';

/// 플랫폼별 DB factory 초기화
void initDatabaseFactory() => initDatabaseFactoryImpl();
