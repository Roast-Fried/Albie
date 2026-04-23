/// 주종 카테고리 한글 레이블
String categoryLabel(String cat) {
  const map = {
    'whisky': '위스키',
    'highball': '하이볼',
    'beer': '맥주',
    'wine': '와인',
    'cocktail': '칵테일',
    'soju': '소주',
    'makgeolli': '막걸리',
    'sake': '사케',
    'other': '기타',
  };
  return map[cat] ?? cat;
}

/// 수량 단위 한글 레이블
String unitLabel(String unit) {
  const map = {
    'glass': '잔',
    'shot': '샷',
    'bottle': '병',
    'can': '캔',
    'ml': 'ml',
    'unknown': '',
  };
  return map[unit] ?? '';
}
