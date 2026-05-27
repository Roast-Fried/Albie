const Object _kUnset = Object();

/// 파서 입력
class ParseInput {
  final String text;
  final String? imagePath;
  final DateTime inputTime;

  ParseInput({required this.text, this.imagePath, DateTime? inputTime})
    : inputTime = inputTime ?? DateTime.now();

  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
}

/// 파서 출력 — AI든 로컬이든 동일한 형태
class ParseResult {
  final String source; // ai_user_key | ai_app_key | local_parser
  final double confidence;
  final List<String> parseWarnings;
  final List<DraftEntry> entries;
  final List<String> foodItems;
  final String? place;
  final String? overallMemo;
  final DateTime? drankAt;

  ParseResult({
    required this.source,
    this.confidence = 0.5,
    this.parseWarnings = const [],
    this.entries = const [],
    this.foodItems = const [],
    this.place,
    this.overallMemo,
    this.drankAt,
  });

  ParseResult copyWith({
    String? source,
    double? confidence,
    List<String>? parseWarnings,
    List<DraftEntry>? entries,
    List<String>? foodItems,
    String? place,
    String? overallMemo,
    DateTime? drankAt,
  }) {
    return ParseResult(
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      parseWarnings: parseWarnings ?? this.parseWarnings,
      entries: entries ?? this.entries,
      foodItems: foodItems ?? this.foodItems,
      place: place ?? this.place,
      overallMemo: overallMemo ?? this.overallMemo,
      drankAt: drankAt ?? this.drankAt,
    );
  }

  factory ParseResult.empty({
    String source = 'local_parser',
    List<String> warnings = const [],
  }) {
    return ParseResult(
      source: source,
      confidence: 0.0,
      parseWarnings: warnings,
      entries: [DraftEntry(liquorNameRaw: '', liquorCategory: 'other')],
    );
  }
}

/// 개별 항목 초안
class DraftEntry {
  /// 기존 drinkEntry 행의 id (편집 모드에서만 유효, 신규 작성 시 null).
  /// update 시 `DrinkLogRepository.update()` 가 이 id 를 보존해 tastingNote CASCADE 손실을 막음.
  final int? id;
  final String? liquorName;
  final int? liquorMasterId;
  final String liquorNameRaw;
  final String liquorCategory;
  final String? ageStatement;
  final double quantityValue;
  final String quantityUnit;
  final bool isEstimated;
  final double? alcoholPercent;

  DraftEntry({
    this.id,
    this.liquorName,
    this.liquorMasterId,
    this.liquorNameRaw = '',
    this.liquorCategory = 'other',
    this.ageStatement,
    this.quantityValue = 1.0,
    this.quantityUnit = 'glass',
    this.isEstimated = true,
    this.alcoholPercent,
  });

  DraftEntry copyWith({
    int? id,
    Object? liquorName = _kUnset,
    // 2026-05-27 Codex audit Finding 3.3/6.4: liquorMasterId 도 sentinel 패턴으로
    // null clear 가능하게. tryMatchByName 의 미매칭 무효화 로직이 의도대로 동작.
    Object? liquorMasterId = _kUnset,
    String? liquorNameRaw,
    String? liquorCategory,
    Object? ageStatement = _kUnset,
    double? quantityValue,
    String? quantityUnit,
    bool? isEstimated,
    Object? alcoholPercent = _kUnset,
  }) {
    return DraftEntry(
      id: id ?? this.id,
      liquorName: identical(liquorName, _kUnset)
          ? this.liquorName
          : liquorName as String?,
      liquorMasterId: identical(liquorMasterId, _kUnset)
          ? this.liquorMasterId
          : liquorMasterId as int?,
      liquorNameRaw: liquorNameRaw ?? this.liquorNameRaw,
      liquorCategory: liquorCategory ?? this.liquorCategory,
      ageStatement: identical(ageStatement, _kUnset)
          ? this.ageStatement
          : ageStatement as String?,
      quantityValue: quantityValue ?? this.quantityValue,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      isEstimated: isEstimated ?? this.isEstimated,
      alcoholPercent: identical(alcoholPercent, _kUnset)
          ? this.alcoholPercent
          : alcoholPercent as double?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'liquorName': liquorName,
    'liquorMasterId': liquorMasterId,
    'liquorNameRaw': liquorNameRaw,
    'liquorCategory': liquorCategory,
    'ageStatement': ageStatement,
    'quantityValue': quantityValue,
    'quantityUnit': quantityUnit,
    'isEstimated': isEstimated,
    'alcoholPercent': alcoholPercent,
  };

  factory DraftEntry.fromJson(Map<String, dynamic> json) {
    // AI 가 liquorName 을 빈 문자열로 반환해도 nullable 로 정규화 — UI 에서
    // "이름 없음" placeholder 노출이 가능하도록.
    final rawName = json['liquorName'] as String?;
    final normalizedName =
        (rawName == null || rawName.trim().isEmpty) ? null : rawName.trim();
    return DraftEntry(
      id: json['id'] as int?,
      liquorName: normalizedName,
      // 2026-05-27 Codex 5 commit audit Finding 4: liquorMasterId 복원 누락
      // (toJson 은 emit, fromJson 은 무시) → roundtrip 손실 회귀. master 매칭
      // 정보가 영구 사라져 archive/stats 카테고리 매핑이 'other' 로 떨어짐.
      liquorMasterId: (json['liquorMasterId'] as num?)?.toInt(),
      liquorNameRaw: normalizedName ?? '',
      liquorCategory: json['liquorCategory'] as String? ?? 'other',
      ageStatement: json['ageStatement'] as String?,
      quantityValue: (json['quantityValue'] as num?)?.toDouble() ?? 1.0,
      quantityUnit: json['quantityUnit'] as String? ?? 'glass',
      isEstimated: json['isEstimated'] as bool? ?? true,
      alcoholPercent: (json['alcoholPercent'] as num?)?.toDouble(),
    );
  }
}
