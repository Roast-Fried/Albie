import '../../domain/entities/drink_log.dart';

/// 음주 기록 백업 직렬화 — 로컬 DrinkLog(+entries+foodItems)를 JSON 스냅샷으로
/// 인코딩/디코딩하는 순수 함수. 네트워크와 분리되어 단위 테스트로 round-trip 검증
/// 가능하다(Supabase 미연결 환경에서도 검증 가능).
///
/// 로컬 id/logId 는 제외한다 — 복원 시 새 기기에서 신규 id 로 재저장되기 때문.
/// rawImagePath 는 보존하되, 다른 기기에서는 파일이 없어 상세 화면이 안내 UI 로
/// 폴백한다(무해).
const int backupSchemaVersion = 1;

Map<String, dynamic> encodeBackup(List<DrinkLog> logs) {
  return {
    'version': backupSchemaVersion,
    'logCount': logs.length,
    'logs': logs.map(_encodeLog).toList(),
  };
}

List<DrinkLog> decodeBackup(Map<String, dynamic> data) {
  final rawLogs = (data['logs'] as List?) ?? const [];
  return rawLogs
      .map((e) => _decodeLog((e as Map).cast<String, dynamic>()))
      .toList();
}

Map<String, dynamic> _encodeLog(DrinkLog log) => {
      'rawInputText': log.rawInputText,
      'rawImagePath': log.rawImagePath,
      'parseSource': log.parseSource,
      'place': log.place,
      'overallMemo': log.overallMemo,
      'drankAt': log.drankAt.toIso8601String(),
      'userConfirmedAt': log.userConfirmedAt?.toIso8601String(),
      'createdAt': log.createdAt.toIso8601String(),
      'updatedAt': log.updatedAt.toIso8601String(),
      'foodItems': log.foodItems,
      'entries': log.entries.map(_encodeEntry).toList(),
    };

Map<String, dynamic> _encodeEntry(DrinkEntry e) => {
      'liquorMasterId': e.liquorMasterId,
      'liquorNameRaw': e.liquorNameRaw,
      'liquorCategory': e.liquorCategory,
      'ageStatement': e.ageStatement,
      'quantityValue': e.quantityValue,
      'quantityUnit': e.quantityUnit,
      'isEstimated': e.isEstimated,
      'alcoholPercent': e.alcoholPercent,
    };

DrinkLog _decodeLog(Map<String, dynamic> m) => DrinkLog(
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
      entries: ((m['entries'] as List?) ?? const [])
          .map((e) => _decodeEntry((e as Map).cast<String, dynamic>()))
          .toList(),
    );

DrinkEntry _decodeEntry(Map<String, dynamic> m) => DrinkEntry(
      liquorMasterId: m['liquorMasterId'] as int?,
      liquorNameRaw: m['liquorNameRaw'] as String? ?? '',
      liquorCategory: m['liquorCategory'] as String? ?? 'other',
      ageStatement: m['ageStatement'] as String?,
      quantityValue: (m['quantityValue'] as num?)?.toDouble() ?? 1.0,
      quantityUnit: m['quantityUnit'] as String? ?? 'glass',
      isEstimated: m['isEstimated'] as bool? ?? true,
      alcoholPercent: (m['alcoholPercent'] as num?)?.toDouble(),
    );
