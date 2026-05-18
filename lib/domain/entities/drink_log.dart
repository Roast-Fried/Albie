/// `copyWith` sentinel — 사용자가 `place: null` / `overallMemo: null` 로 명시적으로
/// 비울 수 있도록 "값 미지정" 과 "null 로 비우기" 를 구분한다.
const Object _kUnset = Object();

class DrinkLog {
  final int? id;
  final String? rawInputText;
  final String? rawImagePath;
  final String parseSource; // ai_user_key | ai_app_key | local_parser | manual
  final String? place;
  final String? overallMemo;
  final DateTime drankAt;
  final DateTime? userConfirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 관계 데이터 (JOIN 시 채워짐)
  final List<DrinkEntry> entries;
  final List<String> foodItems;

  DrinkLog({
    this.id,
    this.rawInputText,
    this.rawImagePath,
    this.parseSource = 'manual',
    this.place,
    this.overallMemo,
    required this.drankAt,
    this.userConfirmedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.entries = const [],
    this.foodItems = const [],
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DrinkLog copyWith({
    int? id,
    String? rawInputText,
    String? rawImagePath,
    String? parseSource,
    Object? place = _kUnset,
    Object? overallMemo = _kUnset,
    DateTime? drankAt,
    DateTime? userConfirmedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DrinkEntry>? entries,
    List<String>? foodItems,
  }) {
    return DrinkLog(
      id: id ?? this.id,
      rawInputText: rawInputText ?? this.rawInputText,
      rawImagePath: rawImagePath ?? this.rawImagePath,
      parseSource: parseSource ?? this.parseSource,
      place: identical(place, _kUnset) ? this.place : place as String?,
      overallMemo: identical(overallMemo, _kUnset)
          ? this.overallMemo
          : overallMemo as String?,
      drankAt: drankAt ?? this.drankAt,
      userConfirmedAt: userConfirmedAt ?? this.userConfirmedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      entries: entries ?? this.entries,
      foodItems: foodItems ?? this.foodItems,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'rawInputText': rawInputText,
      'rawImagePath': rawImagePath,
      'parseSource': parseSource,
      'place': place,
      'overallMemo': overallMemo,
      'drankAt': drankAt.toIso8601String(),
      'userConfirmedAt': userConfirmedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DrinkLog.fromMap(Map<String, dynamic> map) {
    return DrinkLog(
      id: map['id'] as int?,
      rawInputText: map['rawInputText'] as String?,
      rawImagePath: map['rawImagePath'] as String?,
      parseSource: map['parseSource'] as String? ?? 'manual',
      place: map['place'] as String?,
      overallMemo: map['overallMemo'] as String?,
      drankAt: DateTime.parse(map['drankAt'] as String),
      userConfirmedAt: map['userConfirmedAt'] != null
          ? DateTime.parse(map['userConfirmedAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

// 같은 파일에 DrinkEntry도 둔다 — 항상 DrinkLog와 함께 쓰이므로
class DrinkEntry {
  final int? id;
  final int? logId;
  final int? liquorMasterId;
  final String liquorNameRaw;
  final String liquorCategory;
  final String? ageStatement;
  final double quantityValue;
  final String quantityUnit;
  final bool isEstimated;
  final double? alcoholPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  DrinkEntry({
    this.id,
    this.logId,
    this.liquorMasterId,
    required this.liquorNameRaw,
    this.liquorCategory = 'other',
    this.ageStatement,
    this.quantityValue = 1.0,
    this.quantityUnit = 'glass',
    this.isEstimated = true,
    this.alcoholPercent,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  DrinkEntry copyWith({
    int? id,
    int? logId,
    int? liquorMasterId,
    String? liquorNameRaw,
    String? liquorCategory,
    String? ageStatement,
    double? quantityValue,
    String? quantityUnit,
    bool? isEstimated,
    double? alcoholPercent,
  }) {
    return DrinkEntry(
      id: id ?? this.id,
      logId: logId ?? this.logId,
      liquorMasterId: liquorMasterId ?? this.liquorMasterId,
      liquorNameRaw: liquorNameRaw ?? this.liquorNameRaw,
      liquorCategory: liquorCategory ?? this.liquorCategory,
      ageStatement: ageStatement ?? this.ageStatement,
      quantityValue: quantityValue ?? this.quantityValue,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      isEstimated: isEstimated ?? this.isEstimated,
      alcoholPercent: alcoholPercent ?? this.alcoholPercent,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (logId != null) 'logId': logId,
      'liquorMasterId': liquorMasterId,
      'liquorNameRaw': liquorNameRaw,
      'liquorCategory': liquorCategory,
      'ageStatement': ageStatement,
      'quantityValue': quantityValue,
      'quantityUnit': quantityUnit,
      'isEstimated': isEstimated ? 1 : 0,
      'alcoholPercent': alcoholPercent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DrinkEntry.fromMap(Map<String, dynamic> map) {
    return DrinkEntry(
      id: map['id'] as int?,
      logId: map['logId'] as int?,
      liquorMasterId: map['liquorMasterId'] as int?,
      liquorNameRaw: map['liquorNameRaw'] as String? ?? '',
      liquorCategory: map['liquorCategory'] as String? ?? 'other',
      ageStatement: map['ageStatement'] as String?,
      quantityValue: (map['quantityValue'] as num?)?.toDouble() ?? 1.0,
      quantityUnit: map['quantityUnit'] as String? ?? 'glass',
      isEstimated: (map['isEstimated'] as int?) == 1,
      alcoholPercent: (map['alcoholPercent'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
