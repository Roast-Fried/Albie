class UsageQuota {
  final int? id;
  final String dayKey; // YYYY-MM-DD
  final int appDefaultTextCount;
  final int appDefaultImageCount;
  final int userKeyTextCount;
  final int userKeyImageCount;

  static const int maxAppTextPerDay = 10;
  static const int maxAppImagePerDay = 3;

  UsageQuota({
    this.id,
    required this.dayKey,
    this.appDefaultTextCount = 0,
    this.appDefaultImageCount = 0,
    this.userKeyTextCount = 0,
    this.userKeyImageCount = 0,
  });

  bool get canUseAppText => appDefaultTextCount < maxAppTextPerDay;
  bool get canUseAppImage => appDefaultImageCount < maxAppImagePerDay;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'dayKey': dayKey,
      'appDefaultTextCount': appDefaultTextCount,
      'appDefaultImageCount': appDefaultImageCount,
      'userKeyTextCount': userKeyTextCount,
      'userKeyImageCount': userKeyImageCount,
    };
  }

  factory UsageQuota.fromMap(Map<String, dynamic> map) {
    return UsageQuota(
      id: map['id'] as int?,
      dayKey: map['dayKey'] as String,
      appDefaultTextCount: map['appDefaultTextCount'] as int? ?? 0,
      appDefaultImageCount: map['appDefaultImageCount'] as int? ?? 0,
      userKeyTextCount: map['userKeyTextCount'] as int? ?? 0,
      userKeyImageCount: map['userKeyImageCount'] as int? ?? 0,
    );
  }
}
