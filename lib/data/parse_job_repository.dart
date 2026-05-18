import 'package:sqflite/sqflite.dart';
import '../core/exceptions.dart';
import '../domain/entities/parse_job.dart';

class ParseJobRepository {
  final Database _db;

  ParseJobRepository(this._db);

  Future<int> insert(ParseJob job) async {
    try {
      return await _db.insert('parseJob', job.toMap());
    } on DatabaseException catch (e) {
      throw DatabaseError('파싱 기록 저장 실패', cause: e);
    }
  }

  Future<void> linkToLog(int jobId, int logId) async {
    try {
      await _db.update('parseJob', {'logId': logId},
          where: 'id = ?', whereArgs: [jobId]);
    } on DatabaseException catch (e) {
      throw DatabaseError('파싱 기록 연결 실패', cause: e);
    }
  }

  Future<List<ParseJob>> getRecent({int limit = 20}) async {
    final rows = await _db.query('parseJob',
        orderBy: 'createdAt DESC', limit: limit);
    return rows.map((r) => ParseJob.fromMap(r)).toList();
  }

  /// 개인정보 보호 — 모든 parseJob 삭제 (raw 입력 텍스트 포함 영구 삭제).
  ///
  /// `settings_viewmodel.resetAllRecords` 에서 호출. `parseJob.logId` 는
  /// CASCADE SET NULL 이라 log 만 삭제해도 parseJob 은 남는다 → 본 메서드로
  /// rawRequest 포함 전체 삭제.
  Future<void> deleteAll() async {
    try {
      await _db.delete('parseJob');
    } on DatabaseException catch (e) {
      throw DatabaseError('파싱 기록 전체 삭제 실패', cause: e);
    }
  }
}
