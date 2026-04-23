class TastingNote {
  final int? id;
  final int entryId;
  final String? nose;
  final String? palate;
  final String? finish;
  final double? rating; // 0.0 ~ 5.0 (0.5 단위)
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  TastingNote({
    this.id,
    required this.entryId,
    this.nose,
    this.palate,
    this.finish,
    this.rating,
    this.note,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// copyWith — nullable 필드 clear 는 `TastingNote(...)` 직접 생성으로 처리 (whole replacement save).
  TastingNote copyWith({
    int? id,
    int? entryId,
    String? nose,
    String? palate,
    String? finish,
    double? rating,
    String? note,
  }) {
    return TastingNote(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      nose: nose ?? this.nose,
      palate: palate ?? this.palate,
      finish: finish ?? this.finish,
      rating: rating ?? this.rating,
      note: note ?? this.note,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entryId': entryId,
      'nose': nose,
      'palate': palate,
      'finish': finish,
      'rating': rating,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TastingNote.fromMap(Map<String, dynamic> map) {
    return TastingNote(
      id: map['id'] as int?,
      entryId: map['entryId'] as int,
      nose: map['nose'] as String?,
      palate: map['palate'] as String?,
      finish: map['finish'] as String?,
      rating: (map['rating'] as num?)?.toDouble(),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
