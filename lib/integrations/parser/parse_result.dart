/// 파서 입력
class ParseInput {
  final String text;
  final String? imagePath;
  final DateTime inputTime;

  ParseInput({
    required this.text,
    this.imagePath,
    DateTime? inputTime,
  }) : inputTime = inputTime ?? DateTime.now();

  bool get hasImage => imagePath != null;
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
    String? liquorName,
    int? liquorMasterId,
    String? liquorNameRaw,
    String? liquorCategory,
    String? ageStatement,
    double? quantityValue,
    String? quantityUnit,
    bool? isEstimated,
    double? alcoholPercent,
  }) {
    return DraftEntry(
      id: id ?? this.id,
      liquorName: liquorName ?? this.liquorName,
      liquorMasterId: liquorMasterId ?? this.liquorMasterId,
      liquorNameRaw: liquorNameRaw ?? this.liquorNameRaw,
      liquorCategory: liquorCategory ?? this.liquorCategory,
      ageStatement: ageStatement ?? this.ageStatement,
      quantityValue: quantityValue ?? this.quantityValue,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      isEstimated: isEstimated ?? this.isEstimated,
      alcoholPercent: alcoholPercent ?? this.alcoholPercent,
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
    return DraftEntry(
      id: json['id'] as int?,
      liquorName: json['liquorName'] as String?,
      liquorNameRaw: json['liquorName'] as String? ?? '',
      liquorCategory: json['liquorCategory'] as String? ?? 'other',
      ageStatement: json['ageStatement'] as String?,
      quantityValue: (json['quantityValue'] as num?)?.toDouble() ?? 1.0,
      quantityUnit: json['quantityUnit'] as String? ?? 'glass',
      isEstimated: json['isEstimated'] as bool? ?? true,
      alcoholPercent: (json['alcoholPercent'] as num?)?.toDouble(),
    );
  }
}
