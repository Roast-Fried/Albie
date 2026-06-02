import '../../core/exceptions.dart';
import '../../domain/entities/drink_log.dart';
import '../../domain/entities/tasting_note.dart';

/// 음주 기록 백업 직렬화 — 로컬 데이터를 JSON 스냅샷으로 인코딩/디코딩하는 순수
/// 함수(네트워크 분리, round-trip 단위 테스트 가능).
///
/// 백업 단위는 [LogBackup] — 로그 + (항목별 stable key·테이스팅 노트). 복원 시:
/// - 로컬 id/logId/entryId 는 새로 부여되므로 저장하지 않는다.
/// - `masterCanonical`(주류 마스터 canonicalName)로 대상 기기에서 재매칭한다
///   (seed id 가 기기마다 다를 수 있어 FK 실패 방지 — 못 찾으면 null).
/// - 테이스팅 노트는 복원된 새 entryId 에 재연결한다.
const int backupSchemaVersion = 1;

/// 항목 + 복원 보조 정보(마스터 재매칭 key, 테이스팅 노트).
class EntryBackup {
  EntryBackup({required this.entry, this.masterCanonical, this.note});

  final DrinkEntry entry;
  final String? masterCanonical;
  final TastingNote? note;
}

/// 로그 + 항목 백업 묶음.
class LogBackup {
  LogBackup({required this.log, required this.entries});

  final DrinkLog log;
  final List<EntryBackup> entries;
}

Map<String, dynamic> encodeBackup(List<LogBackup> logs) {
  return {
    'version': backupSchemaVersion,
    'logCount': logs.length,
    'logs': logs.map(_encodeLog).toList(),
  };
}

/// 잘못된/구버전 payload 는 [ValidationError] 로 명시 실패(로컬 변경 전에 검출).
List<LogBackup> decodeBackup(Map<String, dynamic> data) {
  final version = data['version'];
  if (version is! int || version != backupSchemaVersion) {
    throw const ValidationError('백업 형식이 호환되지 않아요 (앱 업데이트 필요)');
  }
  final rawLogs = data['logs'];
  if (rawLogs is! List) {
    throw const ValidationError('백업 데이터가 손상되었어요');
  }
  try {
    return rawLogs
        .map((e) => _decodeLog((e as Map).cast<String, dynamic>()))
        .toList();
  } catch (e) {
    if (e is AppError) rethrow;
    throw ValidationError('백업 데이터를 읽을 수 없어요', cause: e);
  }
}

Map<String, dynamic> _encodeLog(LogBackup b) => {
  'rawInputText': b.log.rawInputText,
  'rawImagePath': b.log.rawImagePath,
  'parseSource': b.log.parseSource,
  'place': b.log.place,
  'overallMemo': b.log.overallMemo,
  'drankAt': b.log.drankAt.toIso8601String(),
  'userConfirmedAt': b.log.userConfirmedAt?.toIso8601String(),
  'createdAt': b.log.createdAt.toIso8601String(),
  'updatedAt': b.log.updatedAt.toIso8601String(),
  'foodItems': b.log.foodItems,
  'entries': b.entries.map(_encodeEntry).toList(),
};

Map<String, dynamic> _encodeEntry(EntryBackup e) => {
  'liquorNameRaw': e.entry.liquorNameRaw,
  'liquorCategory': e.entry.liquorCategory,
  'masterCanonical': e.masterCanonical,
  'ageStatement': e.entry.ageStatement,
  'quantityValue': e.entry.quantityValue,
  'quantityUnit': e.entry.quantityUnit,
  'isEstimated': e.entry.isEstimated,
  'alcoholPercent': e.entry.alcoholPercent,
  'tastingNote': e.note == null
      ? null
      : {
          'nose': e.note!.nose,
          'palate': e.note!.palate,
          'finish': e.note!.finish,
          'rating': e.note!.rating,
          'note': e.note!.note,
        },
};

LogBackup _decodeLog(Map<String, dynamic> m) {
  final log = DrinkLog(
    rawInputText: m['rawInputText'] as String?,
    rawImagePath: m['rawImagePath'] as String?,
    parseSource: m['parseSource'] as String? ?? 'manual',
    place: m['place'] as String?,
    overallMemo: m['overallMemo'] as String?,
    drankAt: DateTime.parse(m['drankAt'] as String),
    userConfirmedAt: m['userConfirmedAt'] != null
        ? DateTime.parse(m['userConfirmedAt'] as String)
        : null,
    createdAt: m['createdAt'] != null
        ? DateTime.parse(m['createdAt'] as String)
        : null,
    updatedAt: m['updatedAt'] != null
        ? DateTime.parse(m['updatedAt'] as String)
        : null,
    foodItems: ((m['foodItems'] as List?) ?? const [])
        .map((e) => e as String)
        .toList(),
  );
  final entries = ((m['entries'] as List?) ?? const [])
      .map((e) => _decodeEntry((e as Map).cast<String, dynamic>()))
      .toList();
  return LogBackup(log: log, entries: entries);
}

EntryBackup _decodeEntry(Map<String, dynamic> m) {
  final entry = DrinkEntry(
    liquorNameRaw: m['liquorNameRaw'] as String? ?? '',
    liquorCategory: m['liquorCategory'] as String? ?? 'other',
    ageStatement: m['ageStatement'] as String?,
    quantityValue: (m['quantityValue'] as num?)?.toDouble() ?? 1.0,
    quantityUnit: m['quantityUnit'] as String? ?? 'glass',
    isEstimated: m['isEstimated'] as bool? ?? true,
    alcoholPercent: (m['alcoholPercent'] as num?)?.toDouble(),
  );
  final noteMap = m['tastingNote'];
  TastingNote? note;
  if (noteMap is Map) {
    final nm = noteMap.cast<String, dynamic>();
    note = TastingNote(
      entryId: 0, // 복원 시 새 entryId 로 교체
      nose: nm['nose'] as String?,
      palate: nm['palate'] as String?,
      finish: nm['finish'] as String?,
      rating: (nm['rating'] as num?)?.toDouble(),
      note: nm['note'] as String?,
    );
  }
  return EntryBackup(
    entry: entry,
    masterCanonical: m['masterCanonical'] as String?,
    note: note,
  );
}
