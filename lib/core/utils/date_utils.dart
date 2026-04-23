/// 시간대 자연어 라벨 — 와이어프레임의 "밤 11:30", "저녁 7:00" 처럼 사용.
///
/// 새벽(00~04) / 아침(05~10) / 점심(11~12) / 오후(13~17) / 저녁(18~21) / 밤(22~23)
String timeOfDayKorean(DateTime dt) {
  final h = dt.hour;
  if (h < 5) return '새벽';
  if (h < 11) return '아침';
  if (h < 13) return '점심';
  if (h < 18) return '오후';
  if (h < 22) return '저녁';
  return '밤';
}

/// 6시 컷오프 적용: 00:00~05:59 입력 → 전날로 간주
DateTime applySixHourCutoff(DateTime input) {
  if (input.hour < 6) {
    return DateTime(input.year, input.month, input.day - 1, input.hour,
        input.minute, input.second);
  }
  return input;
}

/// "어제", "그저께" 등 상대 날짜 해석
DateTime? parseRelativeDate(String text, DateTime now) {
  if (text.contains('어제')) {
    return DateTime(now.year, now.month, now.day - 1, 21, 0);
  }
  if (text.contains('그저께') || text.contains('그제')) {
    return DateTime(now.year, now.month, now.day - 2, 21, 0);
  }
  if (text.contains('오늘')) {
    return applySixHourCutoff(now);
  }
  // "지난주", "저번주" → 7일 전
  if (text.contains('지난주') || text.contains('저번주')) {
    return DateTime(now.year, now.month, now.day - 7, 21, 0);
  }
  return null;
}
