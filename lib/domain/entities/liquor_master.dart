import 'dart:convert';

class LiquorMaster {
  final int? id;
  final String canonicalName;
  final String? nameKo;
  final List<String> aliases;
  final String category;
  final String? subcategory;
  final double? defaultAbv;
  final String? country;
  final String? distillery;
  final bool isUserAdded;
  final bool isFavorite;
  final DateTime createdAt;

  LiquorMaster({
    this.id,
    required this.canonicalName,
    this.nameKo,
    this.aliases = const [],
    this.category = 'other',
    this.subcategory,
    this.defaultAbv,
    this.country,
    this.distillery,
    this.isUserAdded = false,
    this.isFavorite = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  LiquorMaster copyWith({
    int? id,
    String? canonicalName,
    String? nameKo,
    List<String>? aliases,
    String? category,
    String? subcategory,
    double? defaultAbv,
    String? country,
    String? distillery,
    bool? isUserAdded,
    bool? isFavorite,
  }) {
    return LiquorMaster(
      id: id ?? this.id,
      canonicalName: canonicalName ?? this.canonicalName,
      nameKo: nameKo ?? this.nameKo,
      aliases: aliases ?? this.aliases,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      defaultAbv: defaultAbv ?? this.defaultAbv,
      country: country ?? this.country,
      distillery: distillery ?? this.distillery,
      isUserAdded: isUserAdded ?? this.isUserAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'canonicalName': canonicalName,
      'nameKo': nameKo,
      'aliasesJson': jsonEncode(aliases),
      'category': category,
      'subcategory': subcategory,
      'defaultAbv': defaultAbv,
      'country': country,
      'distillery': distillery,
      'isUserAdded': isUserAdded ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LiquorMaster.fromMap(Map<String, dynamic> map) {
    List<String> parseAliases(dynamic raw) {
      if (raw == null) return [];
      if (raw is String) {
        try {
          return (jsonDecode(raw) as List).cast<String>();
        } catch (_) {
          return [];
        }
      }
      return [];
    }

    return LiquorMaster(
      id: map['id'] as int?,
      canonicalName: map['canonicalName'] as String? ?? '',
      nameKo: map['nameKo'] as String?,
      aliases: parseAliases(map['aliasesJson']),
      category: map['category'] as String? ?? 'other',
      subcategory: map['subcategory'] as String?,
      defaultAbv: (map['defaultAbv'] as num?)?.toDouble(),
      country: map['country'] as String?,
      distillery: map['distillery'] as String?,
      isUserAdded: (map['isUserAdded'] as int?) == 1,
      isFavorite: (map['isFavorite'] as int?) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// 시드 JSON에서 로드 (aliasesJson 대신 aliases 배열 직접)
  factory LiquorMaster.fromSeedJson(Map<String, dynamic> json) {
    return LiquorMaster(
      canonicalName: json['canonicalName'] as String? ?? '',
      nameKo: json['nameKo'] as String?,
      aliases: (json['aliases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      category: json['category'] as String? ?? 'other',
      subcategory: json['subcategory'] as String?,
      defaultAbv: (json['defaultAbv'] as num?)?.toDouble(),
      country: json['country'] as String?,
      distillery: json['distillery'] as String?,
    );
  }
}
