/// 표준잔 / 순알코올 계산 유틸리티
///
/// 한국 기준: 1 표준잔 = 순알코올 8g (WHO 권고 / 한국주류협회 기준)
/// 에탄올 밀도: 0.7894 g/mL
/// 에탄올(순알코올) 밀도 (g/mL)
const double kEthanolDensity = 0.7894;

/// 한국 기준 1 표준잔 순알코올 양 (g)
const double kStandardDrinkGrams = 8.0;

/// 순알코올량(g) 계산
///
/// [volumeMl] 음료 용량 (mL)
/// [abvPercent] 도수 (%, 예: 5.0 → 5%)
/// 반환값: 순알코올 질량 (g)
double calcPureAlcohol(double volumeMl, double abvPercent) {
  return volumeMl * (abvPercent / 100.0) * kEthanolDensity;
}

/// 표준잔 수 계산 (한국 기준, 1 표준잔 = 8g 순알코올)
///
/// [volumeMl] 음료 용량 (mL)
/// [abvPercent] 도수 (%)
/// 반환값: 표준잔 수
double calcStandardDrinks(double volumeMl, double abvPercent) {
  return calcPureAlcohol(volumeMl, abvPercent) / kStandardDrinkGrams;
}

/// 표준잔 수를 읽기 좋은 문자열로 변환
///
/// 예: 1.75 → "1.8 표준잔", 1.0 → "1.0 표준잔"
String formatStandardDrinks(double drinks) {
  // 소수점 1자리 반올림 표시
  return '${drinks.toStringAsFixed(1)} 표준잔';
}
