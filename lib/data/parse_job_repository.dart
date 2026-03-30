import 'package:sqflite/sqflite.dart';
import '../domain/entities/parse_job.dart';

class ParseJobRepository {
  final Database _db;

  ParseJobRepository(this._db);

  Future<int> insert(ParseJob job) async {
    return _db.insert('parseJob', job.toMap());
  }

  Future<void> linkToLog(int jobId, int logId) async {
    await _db.update('parseJob', {'logId': logId},
        where: 'id = ?', whereArgs: [jobId]);
  }

  Future<List<ParseJob>> getRecent({int limit = 20}) async {
    final rows = await _db.query('parseJob',
        orderBy: 'createdAt DESC', limit: limit);
    return rows.map((r) => ParseJob.fromMap(r)).toList();
  }
}
