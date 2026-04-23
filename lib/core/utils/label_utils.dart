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

/// category + subcategory 조합 한글 레이블 (예: whisky+single_malt → "싱글몰트 위스키").
/// subcategory 가 null 이면 categoryLabel 과 동일.
String subcategoryLabel(String category, String? subcategory) {
  if (subcategory == null) return categoryLabel(category);

  // 위스키 하위 분류
  const whisky = {
    'single_malt': '싱글몰트',
    'blended': '블렌디드',
    'bourbon': '버번',
    'irish': '아이리시',
    'japanese': '재패니즈',
    'rye': '라이',
    'world': '월드',
  };
  // 와인 하위 분류
  const wine = {
    'red': '레드',
    'white': '화이트',
    'rose': '로제',
    'sparkling': '스파클링',
    'champagne': '샴페인',
    'fortified': '주정강화',
  };
  // 맥주 하위 분류
  const beer = {
    'lager': '라거',
    'ale': '에일',
    'stout': '스타우트',
    'wheat': '밀맥주',
    'pilsner': '필스너',
    'cider': '사이다',
  };
  // 증류주 하위 분류
  const spirit = {
    'gin': '진',
    'vodka': '보드카',
    'rum': '럼',
    'tequila': '테킬라',
    'mezcal': '메즈칼',
    'cognac': '꼬냑',
    'brandy': '브랜디',
    'liqueur': '리큐르',
    'absinthe': '압생트',
  };

  final sub = switch (category) {
    'whisky' => whisky[subcategory],
    'wine' => wine[subcategory],
    'beer' => beer[subcategory],
    'spirit' => spirit[subcategory],
    _ => null,
  };
  if (sub == null) return categoryLabel(category);
  return '$sub ${categoryLabel(category)}';
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
