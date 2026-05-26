/// 한글 숫자를 double로 변환
double? parseKoreanNumber(String text) {
  const map = {
    '한': 1.0, '두': 2.0, '세': 3.0, '네': 4.0, '다섯': 5.0,
    '여섯': 6.0, '일곱': 7.0, '여덟': 8.0, '아홉': 9.0, '열': 10.0,
    '반': 0.5,
  };

  // "열두" → 12, "열한" → 11 등 합성 처리
  if (text.startsWith('열') && text.length > 1) {
    final rest = text.substring(1);
    final restVal = map[rest];
    if (restVal != null) return 10.0 + restVal;
  }

  return map[text];
}

/// 단위 문자열 → 표준 단위
String? mapUnit(String text) {
  const map = {
    '잔': 'glass',
    '샷': 'shot',
    '병': 'bottle',
    '캔': 'can',
    '모금': 'unknown',
    '개': 'glass', // "샷 3개" 같은 경우
    '컵': 'glass',
    '글라스': 'glass',
    '파인트': 'glass',
    '잔씩': 'glass',
  };
  return map[text];
}

/// 주종 한글 → category enum
String? mapCategory(String text) {
  const map = {
    '위스키': 'whisky',
    '하이볼': 'highball',
    '맥주': 'beer',
    '와인': 'wine',
    '칵테일': 'cocktail',
    '소주': 'soju',
    '막걸리': 'makgeolli',
    '사케': 'sake',
    '맥': 'beer', // 줄임말
    '생맥': 'beer',
    '생맥주': 'beer',
    '수제맥주': 'beer',
    '크래프트': 'beer',
    '레드와인': 'wine',
    '화이트와인': 'wine',
    '샴페인': 'champagne',
    '보드카': 'vodka',
    '럼': 'rum',
    '진': 'gin',
    '데킬라': 'tequila',
    '브랜디': 'brandy',
    '코냑': 'cognac',
    '리큐어': 'liqueur',
    '리큐르': 'liqueur',
    '스파클링': 'sparkling',
    '스파클링와인': 'sparkling',
    '고량주': 'other',
    '청주': 'sake',
    '동동주': 'makgeolli',
    '탁주': 'makgeolli',
    '술': 'other',
  };
  return map[text];
}
