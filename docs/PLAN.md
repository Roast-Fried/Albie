# 알비(Albi) 구현 계획서

> 기준일: 2026-03-29
> 상태: Draft v1.0
> 목적: Claude Code가 단계적으로 구현에 투입될 수 있는 상세 기술 계획서

---

## 0. 핵심 결정 사항

이 섹션은 구현 전 확정된 판단이다. 구현 중 임의 변경 금지.

### 0-1. 제품 정의

**알비(Albi, 알코올 비서)**는 자연어 한 줄 입력으로 음주 기록 초안을 생성하고,
사용자가 검토/수정 후 저장하는 **로컬 중심** 주류 기록 앱이다.

- 핵심은 **기록 생성 UX**이다. 테이스팅 노트가 아니다.
- AI는 **입력 보조기**이지 주인공이 아니다.
- AI가 없어도 반드시 동작해야 한다.

### 0-2. 기술 스택

| 항목 | 선택 | 이유 |
|------|------|------|
| 프레임워크 | Flutter 3.x + Dart 3.x | 과제 요구사항 |
| 상태관리 | Riverpod (flutter_riverpod) | AsyncNotifier 패턴, 수동 정의 (codegen 미사용) |
| 로컬 DB | sqflite | 구조화 데이터 CRUD + 집계 쿼리 |
| 설정 저장 | shared_preferences | 단순 key-value |
| 민감값 저장 | flutter_secure_storage | API key 암호화 저장 |
| HTTP | dio | interceptor, timeout, retry 지원 |
| 이미지 | image_picker | R1.5 선택 기능 |
| 차트 | fl_chart | 기본 통계 시각화 |
| AI 모델 | gemini-2.5-flash-lite (기본) / gemini-2.5-flash (옵션) | stable + structured output 지원 |

### 0-3. 아키텍처 (MVVM)

```
lib/
├── views/           # View 레이어 (Screen, Widget)
├── viewmodels/      # ViewModel 레이어 (Riverpod AsyncNotifier/StateNotifier)
├── domain/          # Model 레이어 (엔티티)
├── data/            # 데이터 접근 (DAO, Repository 구현)
├── integrations/    # AI adapter, external API client
└── core/            # 공통 유틸, 테마, DB 초기화
```

MVVM 원칙:
- View → ViewModel → Model 단방향 흐름
- 구현체가 1개면 인터페이스 없이 직접 사용
- 불필요한 간접 참조 체인 금지 (Service→Repo→DataSource→DAO 같은 거 안 함)
- Riverpod AsyncNotifier = ViewModel 역할

### 0-4. 릴리스 범위

**R1 필수** (첫 구현 완료 기준)
- 홈 화면 + 자연어 입력창
- 초안 생성 (로컬 파서 + AI 파서)
- 초안 검토/수정 화면
- 기록 저장/조회/수정/삭제
- 마셔본 술 아카이브
- 로컬 주류 마스터 데이터 + 규칙 기반 파서
- Gemini API Key 등록/삭제/모델 선택
- 기본 키 사용량 제한
- 기본 통계
- 설정 화면

**R1.5 선택** (시간 남으면)
- 이미지 첨부 + 이미지 기반 초안 생성
- 알림 로그 화면
- 즐겨찾는 술 / 입력 템플릿

**R2 이후**
- 테이스팅 노트 AI 보완, 업적, 칵테일 구조, 백업/동기화

### 0-5. 절대 금지 사항

1. 저장 전 반드시 검토/수정 화면을 거칠 것 — 자동 저장 금지
2. AI 로직을 UI 위젯에 직접 넣지 말 것 — 반드시 parser adapter 뒤로 격리
3. 건강/의학 판단 기능 금지
4. chain-of-thought 요구 금지, 자유서술형 응답 파싱 금지
5. 이미지 결과 자동 저장 금지
6. console.log/print를 프로덕션에 남기지 말 것

---

## 1. 데이터 모델

### 1-1. ER 관계도

```
drinkLog 1 ──── N drinkEntry
drinkLog 1 ──── N drinkLogFood
drinkEntry N ──── 0..1 liquorMaster
drinkEntry 1 ──── 0..1 tastingNote
drinkLog 1 ──── 1 parseJob (nullable)
(독립) aiConfig
(독립) usageQuota
(독립) appSettings → shared_preferences (DB 테이블 아님)
```

핵심 결정:
- **food와 place는 drinkLog 레벨**이다. entry 레벨이 아니다.
  - 이유: "글렌피딕 한 잔, 벤로막 한 잔, 육회 먹음" → 육회는 세션에 속하지 특정 잔에 속하지 않는다.
  - place도 동일. 한 세션에 장소는 보통 하나다. 2차는 별도 log로 분리.

### 1-2. 테이블 스키마

#### drinkLog (음주 기록 세션)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK AUTOINCREMENT | O | |
| rawInputText | TEXT | X | 사용자 원본 입력 텍스트 |
| rawImagePath | TEXT | X | 첨부 이미지 로컬 경로 |
| parseSource | TEXT | O | `ai_user_key` / `ai_app_key` / `local_parser` / `manual` |
| place | TEXT | X | 장소 |
| overallMemo | TEXT | X | 세션 전체 메모 |
| drankAt | TEXT | O | ISO-8601. 실제 음주 시각. 기본값=입력시각에 6시 컷오프 적용 |
| userConfirmedAt | TEXT | X | 사용자가 검토 완료한 시각 |
| createdAt | TEXT | O | ISO-8601 |
| updatedAt | TEXT | O | ISO-8601 |

#### drinkEntry (개별 음주 항목)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK AUTOINCREMENT | O | |
| logId | INTEGER FK → drinkLog.id | O | ON DELETE CASCADE |
| liquorMasterId | INTEGER FK → liquorMaster.id | X | null이면 미매칭 |
| liquorNameRaw | TEXT | O | 파싱된 원본 이름 (사용자 수정 후 값) |
| liquorCategory | TEXT | O | enum: whisky, highball, beer, wine, cocktail, soju, makgeolli, sake, other |
| ageStatement | TEXT | X | "12년", "15년" 등 |
| quantityValue | REAL | O | 기본값 1.0 |
| quantityUnit | TEXT | O | enum: glass, shot, bottle, can, ml, unknown |
| isEstimated | INTEGER | O | 0 or 1. 기본값 1 |
| alcoholPercent | REAL | X | null이면 모름 |
| createdAt | TEXT | O | |
| updatedAt | TEXT | O | |

설계 결정 (drinkEntry):
- **ageStatement 형식**: `"15년"` 처럼 한글 단위 포함 문자열로 저장. 숫자만 아님. 파서가 "15"를 추출하면 "15년"으로 변환.
- **liquorNameRaw는 항상 채운다**: liquorMasterId가 있어도 liquorNameRaw는 별도 저장. 사용자가 수정한 최종 텍스트 기준.
- **liquorMasterId와 자유입력 관계**: 검토 화면에서 자동완성 목록을 선택하면 liquorMasterId 연결. 목록에 없는 자유 텍스트를 입력하면 liquorMasterId=null, liquorNameRaw만 저장.
- **parseWarnings는 DB에 저장하지 않는다**: 초안 생성 시점에만 유효한 임시 데이터. 검토 화면에서 참고용으로 표시하고, 저장 시 버린다. 디버깅은 parseJob.rawResponse로 충분.

#### drinkLogFood (세션 음식)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK AUTOINCREMENT | O | |
| logId | INTEGER FK → drinkLog.id | O | ON DELETE CASCADE |
| foodName | TEXT | O | |

#### liquorMaster (주류 마스터 데이터)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK AUTOINCREMENT | O | |
| canonicalName | TEXT UNIQUE | O | 정규 이름 (영문 기준) |
| nameKo | TEXT | X | 한글 정규 이름 |
| aliasesJson | TEXT | O | JSON array. 한글 발음 변형 포함. 예: `["벤로막","벤로마크","Benromach"]` |
| category | TEXT | O | whisky, beer, wine, soju, etc. |
| subcategory | TEXT | X | single_malt, blended, bourbon, ipa, lager, etc. |
| defaultAbv | REAL | X | 기본 도수 |
| country | TEXT | X | |
| distillery | TEXT | X | 증류소/양조장 |
| isUserAdded | INTEGER | O | 0=시드, 1=사용자 추가 |
| isFavorite | INTEGER | O | 0 or 1. 기본값 0 |
| createdAt | TEXT | O | |

#### tastingNote (테이스팅 노트)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK AUTOINCREMENT | O | |
| entryId | INTEGER FK → drinkEntry.id | O | UNIQUE. 1:1 관계 |
| nose | TEXT | X | 향 |
| palate | TEXT | X | 맛 |
| finish | TEXT | X | 피니시 |
| rating | REAL | X | 0.0 ~ 5.0 (0.5 단위) |
| note | TEXT | X | 자유 메모 |
| createdAt | TEXT | O | |
| updatedAt | TEXT | O | |

#### parseJob (파싱 작업 로그)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK AUTOINCREMENT | O | |
| logId | INTEGER FK → drinkLog.id | X | 저장 전이면 null |
| sourceType | TEXT | O | `text_only` / `image_only` / `text_plus_image` |
| parserUsed | TEXT | O | `local_parser` / `gemini_flash_lite` / `gemini_flash` |
| status | TEXT | O | `success` / `failed` / `fallback` |
| rawRequest | TEXT | X | AI 요청 본문 (디버깅용) |
| rawResponse | TEXT | X | AI 응답 본문 |
| errorCode | TEXT | X | |
| errorMessage | TEXT | X | |
| durationMs | INTEGER | X | 처리 소요 시간 |
| createdAt | TEXT | O | |

#### aiConfig (AI 연결 설정)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK | O | 항상 1 (싱글톤) |
| provider | TEXT | O | `gemini` (현재 고정) |
| keyMode | TEXT | O | `none` / `app_default` / `user_provided` |
| selectedModel | TEXT | O | `gemini-2.5-flash-lite` / `gemini-2.5-flash` |
| isEnabled | INTEGER | O | 0 or 1 |
| lastValidatedAt | TEXT | X | 마지막 키 검증 시각 |
| lastErrorMessage | TEXT | X | 마지막 오류 메시지 |

주의: 사용자 API key 자체는 `flutter_secure_storage`에 저장. DB에 평문 저장 금지.

#### usageQuota (일일 사용량)

| 컬럼 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | INTEGER PK AUTOINCREMENT | O | |
| dayKey | TEXT UNIQUE | O | `YYYY-MM-DD` |
| appDefaultTextCount | INTEGER | O | 기본키 텍스트 사용 횟수. 기본 0 |
| appDefaultImageCount | INTEGER | O | 기본키 이미지 사용 횟수. 기본 0 |
| userKeyTextCount | INTEGER | O | 사용자키 텍스트 사용 횟수 (통계 표시용, 제한 없음). 기본 0 |
| userKeyImageCount | INTEGER | O | 사용자키 이미지 사용 횟수 (통계 표시용, 제한 없음). 기본 0 |

사용량 제한 기준값 (R1):
- 기본 키 텍스트: **일 10회**
- 기본 키 이미지: **일 3회**
- 사용자 키: **제한 없음** (본인 Gemini 할당량 내)
- 초과 시: 토스트 알림 + 자동 로컬 파서 fallback + 설정에서 사용자 키 등록 유도

### 1-3. DB 버전 관리

- `onCreate`: 전체 테이블 생성 + 시드 데이터 적재
- `onUpgrade`: 버전별 마이그레이션 스크립트
- 초기 버전: `1`
- 시드 데이터는 `assets/seed/` 디렉토리의 JSON 파일에서 로드

### 1-4. 날짜/시간 정책

| 규칙 | 설명 |
|------|------|
| 기본값 | 입력 시점의 로컬 시각 |
| 6시 컷오프 | 00:00~05:59 사이 입력 → `drankAt`은 전날 날짜로 설정 |
| 상대 날짜 | "어제", "그저께" → AI/로컬 파서 모두에서 절대 날짜로 변환 |
| 저장 형식 | ISO-8601 (`2026-03-29T23:30:00+09:00`) |
| 표시 형식 | "3월 29일 (토) 밤 11:30" / "어제" / "2일 전" |

### 1-5. shared_preferences 설정값

DB 테이블이 아닌 `shared_preferences`에 저장하는 앱 설정:

| 키 | 타입 | 기본값 | 설명 |
|----|------|--------|------|
| `onboarding_completed` | bool | false | 온보딩 완료 여부 |
| `default_quantity_unit` | String | "glass" | 기본 수량 단위 |
| `dark_mode` | String | "system" | system / light / dark |
| `six_hour_cutoff_enabled` | bool | true | 6시 컷오프 활성화 |
| `last_placeholder_index` | int | 0 | 홈 placeholder 로테이션 인덱스 |

---

## 2. 로컬 파서 설계

### 2-1. 목적

AI가 꺼져 있거나 사용 불가일 때, 자연어 입력으로부터 **최소한의 구조화된 초안**을 생성한다.
완벽할 필요 없다. 사용자가 검토/수정하기 때문이다.

### 2-2. 파이프라인

```
입력 텍스트
  ↓
[1] 전처리: 공백 정규화, 특수문자 제거, 소문자화(영문)
  ↓
[2] 수량/단위 추출: 정규식 기반
  ↓
[3] 주류명 매칭: liquorMaster 검색
  ↓
[4] 음식 추출: 음식 키워드 사전 매칭
  ↓
[5] 장소 추출: 장소 패턴 매칭
  ↓
[6] 날짜/시간 추출: 상대 날짜 패턴
  ↓
[7] 초안 조립 + confidence 산정 + warnings 생성
  ↓
출력: ParseResult
```

### 2-3. 수량/단위 추출 규칙

정규식 패턴 (한국어 기준):

```
패턴 1: "{숫자}{단위}" → "2잔", "3캔", "1병"
패턴 2: "{한글숫자}{단위}" → "두잔", "세캔", "한병"
패턴 3: "{술이름} {숫자}" → "벤로막 15" (이건 age statement)
패턴 4: "{숫자}ml", "{숫자}미리"
```

한글 숫자 맵핑:
```
한 → 1, 두 → 2, 세 → 3, 네 → 4, 다섯 → 5
여섯 → 6, 일곱 → 7, 여덟 → 8, 아홉 → 9, 열 → 10
반 → 0.5
몇 → null (isEstimated: true)
조금 → null (isEstimated: true, quantityUnit: unknown)
```

단위 맵핑:
```
잔 → glass
샷 → shot
병 → bottle
캔 → can
ml/미리 → ml
모금 → unknown (isEstimated: true)
```

주의: "벤로막 15 두 잔"에서 15는 age statement이고 두는 수량이다.
구분 규칙: **숫자 바로 뒤에 단위가 없으면 age statement 후보**.

### 2-4. 주류명 매칭 전략

4단계 매칭:

```
[1] exact match: aliasesJson에서 정확히 일치
    "벤로마크" → Benromach ✓

[2] alias match: aliasesJson에서 포함 관계
    "벤로막" → aliasesJson contains "벤로막" → Benromach ✓

[3] prefix/contains match: canonicalName 또는 nameKo에서 부분 일치
    "글렌피" → "글렌피딕" partial match → Glenfiddich ✓

[4] no match: liquorMasterId = null, liquorNameRaw = 원본 텍스트
    사용자가 검토 화면에서 수동 선택 가능
```

미매칭 시 동작:
- `liquorMasterId = null`
- `liquorNameRaw = 입력에서 추출한 텍스트`
- `parseWarnings += ["술 이름을 정확히 확인하지 못했습니다"]`

사용자 학습:
- 사용자가 검토 화면에서 미매칭 술을 수동 매칭하면, 해당 alias를 `liquorMaster.aliasesJson`에 추가
- `isUserAdded = false`인 시드 데이터도 alias 추가 가능

### 2-5. 음식 키워드 사전

앱 내장 음식 사전 (초기 ~100개):

```
카테고리별 예시:
- 안주류: 육회, 치즈, 견과류, 초콜릿, 과일, 올리브, 하몽, 프로슈토
- 튀김류: 감자튀김, 치킨, 가라아게, 새우튀김
- 구이류: 삼겹살, 곱창, 갈비, 스테이크
- 해산물: 회, 연어, 굴, 새우
- 면류: 라면, 파스타, 소바
- 분식: 떡볶이, 순대, 김밥
- 기타: 마른안주, 과자, 견과, 빵
```

매칭 방식: 토큰화 후 사전 lookup. 부분 매칭 허용 ("감튀" → "감자튀김").
별칭 맵: `{"감튀": "감자튀김", "치킨너겟": "치킨", "회": "회(생선회)"}` 등

### 2-6. 장소 패턴

```
패턴 1: "~에서" → "에서" 앞 명사구 추출. "바에서" → "바"
패턴 2: "집", "회사", "사무실" → 키워드 직접 매칭
패턴 3: "~바", "~펍", "~라운지" → 접미어 패턴
패턴 4: "홍대", "강남", "이태원" → 지역명 사전 (상위 30개)
```

### 2-7. confidence 산정

```dart
double calculateConfidence(ParseResult result) {
  double score = 0.5; // 기본값

  if (result.entries.isNotEmpty) score += 0.1;
  if (result.entries.any((e) => e.liquorMasterId != null)) score += 0.15;
  if (result.entries.any((e) => e.quantityUnit != 'unknown')) score += 0.1;
  if (result.place != null) score += 0.05;
  if (result.foodItems.isNotEmpty) score += 0.05;
  if (result.warnings.isEmpty) score += 0.05;

  return score.clamp(0.0, 1.0);
}
```

### 2-8. 로컬 파서 한계 (명시적 인정)

로컬 파서가 **못 하는 것**:
- 긴 문장의 의미 해석 ("친구랑 좋은 분위기에서 마신 건데 이름이 기억 안 나")
- 복합 음주 상황 정교한 분리
- 이미지 입력
- 맥락 기반 추론 ("그거 또 마셨어" → "그거"가 뭔지 모름)

이런 경우 → `confidence < 0.5`, `parseWarnings`에 이유 기록, 사용자에게 수동 입력 유도.

---

## 3. AI 통합 설계

### 3-1. 아키텍처

```
┌─────────────────────────────────────────┐
│              ParseOrchestrator          │
│  (전략 선택 + fallback + 후처리)         │
├──────────┬──────────┬───────────────────┤
│ LocalParser │ GeminiTextParser │ GeminiImageParser │
│ (규칙 기반)  │ (텍스트→JSON)     │ (이미지→JSON)      │
└──────────┴──────────┴───────────────────┘
          ↓               ↓                    ↓
     ParseResult      ParseResult          ParseResult
          ↓               ↓                    ↓
     ┌─────────────────────────────────────────┐
     │         PostProcessor                    │
     │  (빈 필드 채우기, 단위 표준화, 중복 제거) │
     └─────────────────────────────────────────┘
                         ↓
                   DraftResult → 검토 화면
```

### 3-2. 인터페이스 정의

```dart
/// 모든 파서가 구현하는 공통 인터페이스
abstract class DraftParser {
  Future<ParseResult> parse(ParseInput input);
}

/// 파서 입력
class ParseInput {
  final String text;
  final String? imagePath;
  final DateTime inputTime;
}

/// 파서 출력
class ParseResult {
  final String source;       // ai_user_key | ai_app_key | local_parser
  final double confidence;
  final List<String> parseWarnings;
  final List<DraftEntry> entries;
  final List<String> foodItems;
  final String? place;
  final String? overallMemo;
  final DateTime? drankAt;
}

/// 개별 항목 초안
class DraftEntry {
  final String? liquorName;
  final String? liquorCategory;
  final String? ageStatement;
  final double quantityValue;
  final String quantityUnit;
  final bool isEstimated;
  final double? alcoholPercent;
}
```

### 3-3. ParseOrchestrator 전략 선택

```dart
Future<ParseResult> orchestrate(ParseInput input) async {
  // 1. 이미지가 있으면 AI만 가능
  if (input.imagePath != null) {
    if (await _canUseAi(isImage: true)) {
      try {
        return await _geminiImageParser.parse(input);
      } catch (e) {
        _logError(e);
        // 이미지는 로컬 파서 불가 → 빈 초안 + 경고
        return ParseResult.empty(
          source: 'local_parser',
          warnings: ['이미지 분석에 실패했습니다. 직접 입력해주세요.'],
        );
      }
    } else {
      return ParseResult.empty(
        source: 'local_parser',
        warnings: ['이미지 분석을 위해 AI 연결이 필요합니다.'],
      );
    }
  }

  // 2. 텍스트만: AI 우선 시도
  if (await _canUseAi(isImage: false)) {
    try {
      final result = await _geminiTextParser.parse(input)
          .timeout(const Duration(seconds: 10));
      await _incrementQuota(isImage: false);
      return result;
    } catch (e) {
      _logError(e);
      // AI 실패 → 로컬 파서 fallback
      final localResult = await _localParser.parse(input);
      return localResult.copyWith(
        parseWarnings: [
          ...localResult.parseWarnings,
          'AI 연결 실패로 로컬 파서를 사용했습니다.',
        ],
      );
    }
  }

  // 3. AI 사용 불가 → 로컬 파서
  return await _localParser.parse(input);
}
```

### 3-4. AI 사용 가능 판단

```dart
Future<bool> _canUseAi({required bool isImage}) async {
  final config = await _aiConfigRepo.get();
  if (!config.isEnabled) return false;

  if (config.keyMode == 'user_provided') {
    // 사용자 키: 항상 가능 (본인 한도 내)
    return true;
  }

  if (config.keyMode == 'app_default') {
    // 기본 키: 일일 제한 확인
    final quota = await _quotaRepo.getToday();
    if (isImage) {
      return quota.appDefaultImageCount < 3;  // 일 3회
    } else {
      return quota.appDefaultTextCount < 10;  // 일 10회
    }
  }

  return false;
}
```

### 3-5. Gemini Structured Output 스키마

AI에게 보내는 response schema:

```json
{
  "type": "object",
  "properties": {
    "confidence": { "type": "number" },
    "parseWarnings": {
      "type": "array",
      "items": { "type": "string" }
    },
    "drankAt": { "type": "string", "nullable": true },
    "place": { "type": "string", "nullable": true },
    "overallMemo": { "type": "string", "nullable": true },
    "foodItems": {
      "type": "array",
      "items": { "type": "string" }
    },
    "entries": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "liquorName": { "type": "string", "nullable": true },
          "liquorCategory": {
            "type": "string",
            "enum": ["whisky","highball","beer","wine","cocktail","soju","makgeolli","sake","other"]
          },
          "ageStatement": { "type": "string", "nullable": true },
          "quantityValue": { "type": "number" },
          "quantityUnit": {
            "type": "string",
            "enum": ["glass","shot","bottle","can","ml","unknown"]
          },
          "isEstimated": { "type": "boolean" },
          "alcoholPercent": { "type": "number", "nullable": true }
        },
        "required": ["liquorCategory","quantityValue","quantityUnit","isEstimated"]
      }
    }
  },
  "required": ["confidence","parseWarnings","entries","foodItems"]
}
```

### 3-6. Gemini 시스템 프롬프트

```
너는 음주 기록 파서다. 사용자가 입력한 자연어 문장에서 음주 정보를 추출해 JSON으로 반환한다.

규칙:
1. entries는 1개 이상 반환한다.
2. 확실하지 않은 필드는 null로 둔다.
3. 양을 모르면 quantityValue=1, quantityUnit="unknown", isEstimated=true로 설정한다.
4. 술 종류를 모르면 liquorCategory="other"로 설정한다.
5. "어제", "그저께" 등 상대 날짜는 현재 날짜 기준으로 ISO-8601 절대 날짜로 변환한다. 현재 날짜: {currentDate}
6. 00:00~05:59 사이라면 전날로 간주한다.
7. 건강, 의학, 체내 알코올 관련 내용은 무시한다.
8. 확신도가 낮은 항목은 parseWarnings에 이유를 적는다.
```

### 3-7. 에러 처리 매트릭스

| 상황 | 동작 | 사용자 알림 |
|------|------|-------------|
| 네트워크 끊김 | 로컬 파서 fallback | 토스트: "AI 연결 실패, 로컬 파서로 생성했습니다" |
| API 키 무효 | 로컬 파서 fallback + aiConfig.lastErrorMessage 갱신 | 토스트 + 설정에서 키 확인 유도 |
| 응답 스키마 불일치 | 로컬 파서 fallback + parseJob 에러 로깅 | 토스트: "AI 응답 처리 실패" |
| 타임아웃 (10초) | 로컬 파서 fallback | 토스트: "AI 응답 지연, 로컬 파서로 생성했습니다" |
| 일일 제한 초과 | 로컬 파서 사용 | 토스트: "오늘 AI 사용 횟수를 모두 사용했습니다" + 설정 유도 |
| Gemini 429 (rate limit) | 로컬 파서 fallback | 토스트: "AI 요청이 많습니다. 잠시 후 다시 시도해주세요" |
| Gemini 500 (server error) | 로컬 파서 fallback | 토스트: "AI 서비스 일시 장애" |
| 이미지 + AI 불가 | 빈 초안 + 경고 | "이미지 분석을 위해 AI 연결이 필요합니다" |

### 3-8. API Key 보안

- 앱 기본 키: 빌드 시 환경변수로 주입, 소스코드에 하드코딩 금지
  - 과제 시연용이므로 `.env` 또는 `--dart-define`으로 주입
- 사용자 키: `flutter_secure_storage`에 암호화 저장
- 키 등록 화면에 **무료 티어 데이터 사용 안내** 필수 표시:
  > "무료 Gemini API를 사용하면 입력 내용이 Google 제품 개선에 사용될 수 있습니다."

---

## 4. 화면 및 UX 명세

### 4-1. 네비게이션 구조

```
BottomNavigationBar (3탭):
├── [0] 홈 (HomeScreen)
├── [1] 기록 (LogListScreen)
└── [2] 더보기 (MoreScreen)
         ├── 술 아카이브 (ArchiveScreen)
         ├── 통계 (StatsScreen)
         └── 설정 (SettingsScreen)
              └── AI 연결 (AiSettingsScreen)
```

독립 화면 (push):
- 초안 검토/수정 (DraftReviewScreen)
- 기록 상세 (LogDetailScreen)
- 기록 수정 (LogEditScreen)
- 아카이브 상세 (ArchiveDetailScreen)

### 4-2. 홈 화면 (HomeScreen)

```
┌──────────────────────────────┐
│  알비                  [🔔]  │  ← 앱 타이틀 + 알림/로그 아이콘
├──────────────────────────────┤
│  ┌────────────────────────┐  │
│  │  최근 기록              │  │  ← 최근 drinkLog 1~3개 카드
│  │  ┌──────┐ ┌──────┐    │  │     수평 스크롤
│  │  │3/28  │ │3/27  │    │  │     탭 → LogDetailScreen
│  │  │벤로막│ │하이볼│    │  │
│  │  │15 2잔│ │2잔   │    │  │
│  │  └──────┘ └──────┘    │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │  ← 자연어 입력 영역 (화면 중앙)
│  │ 오늘 뭐 마셨어?        │  │     placeholder 랜덤 로테이션
│  │                        │  │
│  └────────────────────────┘  │
│                              │
│  [✨ AI로 생성] [✏️ 직접 입력] │  ← 빠른 액션 버튼
│                              │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │  ← 키보드에 가려져도 괜찮은 영역
│  최근 마셔본 술 (수평 칩)    │
│  이번 달 기록 3회            │
│  추천 입력 예시              │
├──────────────────────────────┤
│  [🏠 홈] [📋 기록] [⋯ 더보기] │  ← BottomNav
└──────────────────────────────┘
```

입력 동작:
- 텍스트 입력 후 "AI로 생성" → ParseOrchestrator → DraftReviewScreen
- 텍스트 입력 후 "직접 입력" → 빈 폼의 DraftReviewScreen (rawInputText만 저장)
- 입력창 비어있으면 "AI로 생성" 비활성화

placeholder 예시 (랜덤):
- "나 오늘 벤로막 15 두 잔 마셨어"
- "하이볼 한 잔이랑 육회 먹음"
- "글렌피딕 12 바에서 한 잔"
- "맥주 3캔 마심"
- "위스키 조금 마셨는데 이름은 기억 안 남"

### 4-3. 초안 검토/수정 화면 (DraftReviewScreen)

이 화면이 알비의 **가장 중요한 화면**이다. 모든 기록은 반드시 이 화면을 거친다.

```
┌──────────────────────────────┐
│  ← 기록 검토        [저장]   │
├──────────────────────────────┤
│  ┌─ 출처 ─────────────────┐  │
│  │ [🤖 AI (기본키)] conf 0.85│ ← 출처 칩 + confidence
│  └────────────────────────┘  │
│                              │
│  📅 날짜: 3월 29일 (토)  [변경]│ ← drankAt (drinkLog 레벨)
│  📍 장소: 바             [변경]│ ← place (drinkLog 레벨)
│                              │
│  ── 항목 1 ──────────────── │
│  술: [벤로마크        ▾]     │ ← liquorMaster 매칭 or 자유입력
│  주종: [위스키         ▾]    │ ← liquorCategory 드롭다운
│  연산: [15년              ]  │ ← ageStatement
│  양:  [2] [잔 ▾]            │ ← quantityValue + unit
│  도수: [43.0 %]             │ ← alcoholPercent
│  ⚠️ "수량이 추정치입니다"    │ ← parseWarnings (해당 필드 하이라이트)
│                              │
│  ── 항목 2 ──────────────── │
│  (동일 구조)                 │
│  [+ 항목 추가]               │ ← entry 추가 가능
│                              │
│  🍽️ 음식: [육회] [치즈] [+]  │ ← foodItems (drinkLog 레벨)
│                              │
│  📝 메모                     │
│  [                        ]  │ ← overallMemo
│                              │
│  [저장]                      │
└──────────────────────────────┘
```

동작 규칙:
- 모든 필드 편집 가능
- entry 추가/삭제 가능 (최소 1개 유지)
- 술 이름 필드: 자유 텍스트 + liquorMaster 자동완성 드롭다운
- confidence < 0.7인 필드: 주황색 테두리로 하이라이트
- parseWarnings: 해당 필드 아래 작은 텍스트로 표시
- 저장 시 `userConfirmedAt` 기록

### 4-4. 기록 목록 화면 (LogListScreen)

```
┌──────────────────────────────┐
│  기록 목록           [🔍]    │
├──────────────────────────────┤
│  ── 2026년 3월 ──           │
│  ┌────────────────────────┐  │
│  │ 3/29 (토) 밤 11:30     │  │
│  │ 벤로마크 15년 2잔       │  │
│  │ 🍽 육회, 치즈  📍 바    │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │ 3/28 (금) 저녁 8:00    │  │
│  │ 하이볼 2잔, 맥주 1캔    │  │
│  │ 🍽 감자튀김  📍 집      │  │
│  └────────────────────────┘  │
│  ...                         │
├──────────────────────────────┤
│  [🏠 홈] [📋 기록] [⋯ 더보기] │
└──────────────────────────────┘
```

기능:
- 날짜순 내림차순 (최신 먼저)
- 검색: 멀티 테이블 LIKE 검색. 쿼리 예시:
  ```sql
  SELECT DISTINCT dl.* FROM drinkLog dl
  LEFT JOIN drinkEntry de ON de.logId = dl.id
  LEFT JOIN drinkLogFood df ON df.logId = dl.id
  WHERE dl.rawInputText LIKE '%keyword%'
     OR de.liquorNameRaw LIKE '%keyword%'
     OR dl.place LIKE '%keyword%'
     OR df.foodName LIKE '%keyword%'
  ORDER BY dl.drankAt DESC
  ```
- 탭 → LogDetailScreen
- 롱프레스 → 삭제 확인 다이얼로그
- 빈 상태: "아직 기록이 없어요. 오늘 뭐 마셨어?"

### 4-5. 기록 상세 화면 (LogDetailScreen)

- drinkLog + 소속 entries + foods + tastingNotes 전체 표시
- [수정] → LogEditScreen (DraftReviewScreen과 동일 구조, 기존 데이터 채움)
- [삭제] → 확인 다이얼로그 → log 단위 삭제 (cascade)
- 테이스팅 노트 섹션: 각 entry별로 [노트 작성] 버튼
- 원본 입력 텍스트 표시 (접을 수 있는 섹션)

### 4-6. 술 아카이브 화면 (ArchiveScreen)

```
┌──────────────────────────────┐
│  마셔본 술            [🔍]   │
├──────────────────────────────┤
│  [전체][위스키][맥주][와인]...│ ← 카테고리 필터 칩
├──────────────────────────────┤
│  ┌────────────────────────┐  │
│  │ 벤로마크 (Benromach)    │  │
│  │ 위스키 · 3회 기록       │  │
│  │ 최근: 3/29 · ★ 4.0    │  │
│  │ [♡ 즐겨찾기]           │  │
│  └────────────────────────┘  │
│  ┌────────────────────────┐  │
│  │ 글렌피딕 (Glenfiddich)  │  │
│  │ 위스키 · 5회 기록       │  │
│  │ 최근: 3/25 · ★ 4.5    │  │
│  └────────────────────────┘  │
│  ...                         │
└──────────────────────────────┘
```

데이터 소스: `drinkEntry` JOIN `liquorMaster` 기준 집계
- 기록 횟수 (`COUNT`)
- 마지막 기록일 (`MAX(drankAt)`)
- 평균 평점 (tastingNote JOIN, `AVG(rating)`)
- 즐겨찾기 상태: `liquorMaster`에 `isFavorite` 컬럼 추가 (boolean)

검색: canonicalName, nameKo, aliasesJson 대상

### 4-7. 통계 화면 (StatsScreen)

R1 범위:

| 통계 항목 | 쿼리 기준 | 시각화 |
|-----------|-----------|--------|
| 총 기록 수 | `COUNT(drinkLog)` | 숫자 카드 |
| 최근 7일 기록 수 | `WHERE drankAt >= 7일전` | 숫자 카드 |
| 이번 달 기록 수 | `WHERE drankAt >= 이번달 1일` | 숫자 카드 |
| 주종별 빈도 | `GROUP BY liquorCategory` | 파이 차트 |
| 가장 많이 기록한 술 TOP 5 | `GROUP BY liquorNameRaw ORDER BY COUNT DESC LIMIT 5` | 바 차트 |
| 월별 기록 수 (최근 6개월) | `GROUP BY month(drankAt)` | 라인 차트 |

### 4-8. 설정 화면 (SettingsScreen)

```
┌──────────────────────────────┐
│  설정                        │
├──────────────────────────────┤
│  AI 연결                     │
│  ┌────────────────────────┐  │
│  │ AI 사용: [ON]          │  │
│  │ 모드: 기본 제한형       │  │
│  │ 오늘 사용: 3/10회       │  │
│  │ [AI 설정 상세 →]       │  │
│  └────────────────────────┘  │
│                              │
│  일반                        │
│  ┌────────────────────────┐  │
│  │ 다크 모드: [시스템 따름]│  │
│  │ 기본 수량 단위: [잔]    │  │
│  │ 6시 컷오프: [ON]       │  │
│  └────────────────────────┘  │
│                              │
│  데이터                      │
│  ┌────────────────────────┐  │
│  │ 전체 기록 수: 42건      │  │
│  │ 마셔본 술: 15종         │  │
│  │ [데이터 초기화]         │  │
│  └────────────────────────┘  │
│                              │
│  정보                        │
│  ┌────────────────────────┐  │
│  │ 버전: 1.0.0            │  │
│  │ [오픈소스 라이선스]     │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

### 4-9. AI 설정 상세 화면 (AiSettingsScreen)

```
┌──────────────────────────────┐
│  ← AI 연결 설정              │
├──────────────────────────────┤
│  AI 사용                     │
│  [ON / OFF 토글]             │
│                              │
│  연결 모드                    │
│  ○ 기본 제한형 (일 10회)     │
│  ● 내 API Key 사용           │
│                              │
│  API Key                     │
│  [AIza••••••••••••••••]      │
│  마지막 검증: 3/29 22:00 ✓   │
│  [키 변경] [키 삭제]         │
│                              │
│  모델 선택                    │
│  ○ Flash Lite (빠름, 기본)   │
│  ● Flash (더 정확)           │
│                              │
│  오늘 사용량                  │
│  텍스트: 7회                 │
│  이미지: 1회                 │
│                              │
│  ⓘ 무료 Gemini API 사용 시   │
│  입력 내용이 Google 제품 개선 │
│  에 사용될 수 있습니다.       │
│                              │
│  최근 처리 로그               │
│  ┌────────────────────────┐  │
│  │ 22:30 텍스트 파싱 ✓    │  │
│  │ 22:15 텍스트 파싱 ✓    │  │
│  │ 21:00 이미지 파싱 ✗    │  │
│  │        "timeout"       │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

### 4-10. 온보딩 (첫 실행)

첫 실행 시 간단한 2~3장 온보딩:

1. **"알비에 오신 걸 환영합니다"** — 한 줄 입력으로 기록하세요
2. **"AI 없이도 동작합니다"** — 기본으로 로컬 파서가 도와드립니다. AI를 연결하면 더 정확해집니다.
3. **"시작하기"** → 홈 화면

`shared_preferences`에 `onboarding_completed: true` 저장.

---

## 5. 시드 데이터 설계

### 5-1. 위스키 마스터 (50개)

카테고리별 구성:
- 싱글몰트 스카치 (20개): Glenfiddich, Macallan, Laphroaig, Lagavulin, Talisker, Highland Park, Balvenie, Glenmorangie, Ardbeg, Oban, Dalmore, Aberlour, Benromach, Bowmore, Caol Ila, Cragganmore, Glen Grant, Glendronach, Springbank, Bruichladdich
- 블렌디드 스카치 (5개): Johnnie Walker, Chivas Regal, Ballantine's, Dewar's, Monkey Shoulder
- 버번/아메리칸 (10개): Jack Daniel's, Maker's Mark, Wild Turkey, Buffalo Trace, Woodford Reserve, Four Roses, Jim Beam, Bulleit, Knob Creek, Eagle Rare
- 아이리시 (3개): Jameson, Bushmills, Redbreast
- 일본 (7개): Yamazaki, Hakushu, Hibiki, Nikka From The Barrel, Nikka Coffey Grain, Taketsuru, Ichiro's Malt
- 기타 (5개): Kavalan, Amrut, Starward, Paul John, Mackmyra

### 5-2. 위스키 외 주류 (30개)

- 맥주 (10개): 카스, 하이트, 클라우드, 테라, 켈리, 기네스, 하이네켄, 아사히, 삿포로, 호가든
- 소주 (5개): 참이슬, 처음처럼, 진로, 좋은데이, 새로
- 막걸리 (3개): 장수막걸리, 서울막걸리, 느린마을막걸리
- 와인 (5개): (일반적 품종명) 카베르네소비뇽, 피노누아, 샤르도네, 리슬링, 소비뇽블랑
- 사케 (3개): 닷사이, 쿠보타, 하쿠쓰루
- 칵테일 (4개): 하이볼, 모히토, 마가리타, 올드패션드

### 5-3. 별칭(alias) 예시

```json
{
  "canonicalName": "Benromach",
  "nameKo": "벤로마크",
  "aliasesJson": ["벤로마크","벤로막","벤로맥","benromach","Benromach"],
  "category": "whisky",
  "subcategory": "single_malt",
  "defaultAbv": 43.0,
  "country": "Scotland",
  "distillery": "Benromach"
}
```

```json
{
  "canonicalName": "Highball",
  "nameKo": "하이볼",
  "aliasesJson": ["하이볼","highball","하이보루","위스키소다"],
  "category": "highball",
  "subcategory": null,
  "defaultAbv": null,
  "country": null,
  "distillery": null
}
```

### 5-4. 음식 사전 (별도 JSON)

```json
[
  {"name": "육회", "aliases": ["육회","유케"]},
  {"name": "치즈", "aliases": ["치즈","cheese","치즈플래터"]},
  {"name": "감자튀김", "aliases": ["감자튀김","감튀","프렌치프라이","프라이"]},
  {"name": "치킨", "aliases": ["치킨","chicken","닭","치느님"]},
  ...
]
```

### 5-5. place_keywords.json 구조

```json
{
  "suffixes": ["바", "펍", "라운지", "이자카야", "포차", "호프"],
  "exactMatch": ["집", "회사", "사무실", "학교", "기숙사"],
  "areas": ["홍대", "강남", "이태원", "종로", "신촌", "건대", "합정", "망원",
            "성수", "을지로", "연남", "압구정", "청담", "삼성", "잠실",
            "신림", "대학로", "명동", "광화문", "여의도",
            "해운대", "서면", "광안리", "대구동성로", "전주한옥마을",
            "제주시", "서귀포", "경리단길", "한남동", "용산"]
}
```

### 5-6. 파일 구조

```
assets/
└── seed/
    ├── liquor_master.json      # 위스키 + 기타 주류 80개
    ├── food_dictionary.json    # 음식 사전 ~100개
    └── place_keywords.json     # 장소 키워드 ~30개
```

### 5-7. 이미지 저장 정책 (R1.5)

- 저장 위치: `getApplicationDocumentsDirectory()/images/`
- 파일명: `{logId}_{timestamp}.jpg`
- drinkLog 삭제 시: 연결된 이미지 파일도 함께 삭제
- 크기 제한: 원본 저장 (리사이징은 R2)

---

## 6. 디렉토리 구조

```
lib/
├── main.dart
├── app.dart                          # MaterialApp, 라우팅, 테마
│
├── core/
│   ├── constants/
│   │   ├── app_constants.dart        # 앱 상수 (quota 제한값 등)
│   │   └── liquor_categories.dart    # enum 정의
│   ├── database/
│   │   ├── database_helper.dart      # sqflite 초기화, 마이그레이션
│   │   └── seed_loader.dart          # assets JSON → DB 적재
│   ├── theme/
│   │   └── app_theme.dart            # 라이트/다크 테마
│   ├── utils/
│   │   ├── date_utils.dart           # 6시 컷오프, 상대날짜 변환
│   │   └── string_utils.dart         # 정규화, 한글 숫자 변환
│   └── router/
│       └── app_router.dart           # 라우트 정의
│
├── domain/
│   ├── entities/
│   │   ├── drink_log.dart
│   │   ├── drink_entry.dart
│   │   ├── drink_log_food.dart
│   │   ├── liquor_master.dart
│   │   ├── tasting_note.dart
│   │   ├── parse_job.dart
│   │   ├── ai_config.dart
│   │   └── usage_quota.dart
│   └── repositories/
│       ├── drink_log_repository.dart       # abstract (drinkLogFood 포함)
│       ├── liquor_master_repository.dart   # abstract
│       ├── tasting_note_repository.dart    # abstract
│       ├── parse_job_repository.dart       # abstract
│       ├── ai_config_repository.dart       # abstract
│       └── usage_quota_repository.dart     # abstract
│
├── data/
│   ├── dao/
│   │   ├── drink_log_dao.dart              # drinkLog + drinkEntry + drinkLogFood 통합
│   │   ├── liquor_master_dao.dart
│   │   ├── tasting_note_dao.dart
│   │   ├── parse_job_dao.dart
│   │   ├── ai_config_dao.dart
│   │   └── usage_quota_dao.dart
│   └── repositories/
│       ├── drink_log_repository_impl.dart
│       ├── liquor_master_repository_impl.dart
│       ├── tasting_note_repository_impl.dart
│       ├── parse_job_repository_impl.dart
│       ├── ai_config_repository_impl.dart
│       └── usage_quota_repository_impl.dart
│
├── integrations/
│   ├── parser/
│   │   ├── draft_parser.dart               # abstract interface
│   │   ├── parse_input.dart                # 입력 모델
│   │   ├── parse_result.dart               # 출력 모델
│   │   ├── local_rule_parser.dart          # 로컬 규칙 기반 파서
│   │   ├── gemini_text_parser.dart         # Gemini 텍스트 파서
│   │   ├── gemini_image_parser.dart        # Gemini 이미지 파서 (R1.5)
│   │   ├── parse_orchestrator.dart         # 전략 선택 + fallback
│   │   └── post_processor.dart             # 후처리 (단위 표준화 등)
│   └── gemini/
│       ├── gemini_client.dart              # HTTP client wrapper
│       ├── gemini_schemas.dart             # request/response 스키마
│       └── gemini_config.dart              # endpoint, model 상수
│
├── application/
│   ├── providers/
│   │   ├── database_provider.dart          # DB 인스턴스
│   │   ├── repository_providers.dart       # repository DI
│   │   ├── parser_providers.dart           # parser DI
│   │   ├── home_provider.dart              # 홈 화면 상태
│   │   ├── draft_review_provider.dart      # 초안 검토 상태
│   │   ├── log_list_provider.dart          # 기록 목록 상태
│   │   ├── archive_provider.dart           # 아카이브 상태
│   │   ├── stats_provider.dart             # 통계 상태
│   │   └── ai_settings_provider.dart       # AI 설정 상태
│   └── use_cases/
│       ├── create_draft_use_case.dart      # 입력 → 초안 생성
│       ├── save_log_use_case.dart          # 초안 → DB 저장
│       └── validate_api_key_use_case.dart  # API key 검증
│
└── presentation/
    ├── home/
    │   ├── home_screen.dart
    │   └── widgets/
    │       ├── recent_logs_widget.dart
    │       ├── input_section_widget.dart
    │       └── quick_stats_widget.dart
    ├── draft_review/
    │   ├── draft_review_screen.dart
    │   └── widgets/
    │       ├── entry_card_widget.dart
    │       ├── food_chips_widget.dart
    │       └── source_badge_widget.dart
    ├── log/
    │   ├── log_list_screen.dart
    │   ├── log_detail_screen.dart
    │   └── log_edit_screen.dart
    ├── archive/
    │   ├── archive_screen.dart
    │   └── archive_detail_screen.dart
    ├── stats/
    │   └── stats_screen.dart
    ├── settings/
    │   ├── settings_screen.dart
    │   └── ai_settings_screen.dart
    ├── onboarding/
    │   └── onboarding_screen.dart
    └── common/
        ├── empty_state_widget.dart
        ├── loading_widget.dart
        └── error_widget.dart
```

---

## 7. 구현 Phase 상세

### Phase 1: 프로젝트 뼈대 (예상: 1~2시간)

**목표**: Flutter 앱이 빌드되고 빈 화면이 뜬다.

태스크:
1. `flutter create albi` 실행
2. `pubspec.yaml`에 패키지 추가
3. 디렉토리 구조 생성 (위 6번 기준)
4. `app_theme.dart` 기본 테마 (Material 3)
5. `app_router.dart` 라우트 정의 (빈 화면들)
6. `main.dart` → ProviderScope 감싸기
7. BottomNavigationBar 3탭 셸 구현
8. 빌드 확인

**완료 기준**: `flutter run` 시 3탭 네비게이션이 동작하는 빈 앱

### Phase 2: 도메인 + DB (예상: 2~3시간)

**목표**: 모든 엔티티와 테이블이 정의되고, CRUD가 동작한다.

태스크:
1. domain/entities 전체 구현
2. database_helper.dart (sqflite 초기화, CREATE TABLE)
3. dao 전체 구현 (raw SQL)
4. repository 인터페이스 + 구현체
5. Riverpod provider로 DI 연결
6. seed JSON 파일 작성 (liquor_master.json, food_dictionary.json, place_keywords.json)
7. seed_loader.dart 구현 (첫 실행 시 JSON → DB 적재)
8. 단위 테스트: DAO CRUD

**완료 기준**: DB에 시드 데이터가 적재되고, drinkLog 생성/조회/수정/삭제가 테스트 통과

### Phase 3: 로컬 파서 (예상: 3~4시간)

**목표**: AI 없이 자연어 입력 → 구조화 초안이 생성된다.

태스크:
1. parse_input.dart, parse_result.dart 모델 구현
2. draft_parser.dart 인터페이스
3. string_utils.dart (한글 숫자 변환, 정규화)
4. date_utils.dart (6시 컷오프, 상대 날짜)
5. local_rule_parser.dart 핵심 구현:
   - 수량/단위 추출 (정규식)
   - 주류명 매칭 (4단계)
   - 음식 추출
   - 장소 추출
   - confidence 산정
6. post_processor.dart (단위 표준화, 중복 제거)
7. parse_orchestrator.dart (로컬만 우선 연결)
8. 단위 테스트: 최소 15개 입력 케이스

테스트 케이스 (필수):
```
"나 오늘 벤로막 15 두 잔 마셨어"
  → entries: [{liquorName: "벤로마크", ageStatement: "15년", qty: 2, unit: glass}]

"글렌피딕 12 한 잔, 육회 먹음"
  → entries: [{liquorName: "글렌피딕", ageStatement: "12년", qty: 1}]
  → foodItems: ["육회"]

"하이볼 두 잔에 감자튀김, 집"
  → entries: [{liquorName: "하이볼", qty: 2, unit: glass}]
  → foodItems: ["감자튀김"], place: "집"

"맥주 3캔 마심"
  → entries: [{category: beer, qty: 3, unit: can}]

"위스키 조금 마셨는데 이름은 기억 안 남"
  → entries: [{category: whisky, qty: null, unit: unknown, isEstimated: true}]
  → warnings: ["술 이름을 확인하지 못했습니다", "수량이 추정치입니다"]

"잭다니엘 샷 3개"
  → entries: [{liquorName: "Jack Daniel's", qty: 3, unit: shot}]

"소주 반 병이랑 삼겹살"
  → entries: [{category: soju, qty: 0.5, unit: bottle}]
  → foodItems: ["삼겹살"]

"어제 강남에서 와인 한 잔"
  → entries: [{category: wine, qty: 1, unit: glass}]
  → place: "강남", drankAt: 어제 날짜

"칵테일 한 잔 마시고 맥주 두 잔 더 마심"
  → entries: [{category: cocktail, qty: 1}, {category: beer, qty: 2}]

"야마자키 12년 니트로 한 잔, 하이볼 한 잔"
  → entries: [{liquorName: "야마자키", age: "12년", qty: 1}, {liquorName: "하이볼", qty: 1}]
```

**완료 기준**: 위 테스트 케이스 중 7개 이상 올바른 초안 생성

### Phase 4: 홈 + 입력 + 검토 UI (예상: 4~5시간)

**목표**: 핵심 사용자 플로우가 동작한다. 입력 → 초안 → 검토 → 저장.

태스크:
1. home_screen.dart + 위젯들
2. input_section_widget.dart (입력창 + 액션 버튼)
3. home_provider.dart (최근 로그 조회, 입력 상태)
4. create_draft_use_case.dart (입력 → orchestrator → ParseResult)
5. draft_review_provider.dart (초안 상태 관리)
6. draft_review_screen.dart (폼 전체)
7. entry_card_widget.dart (개별 entry 편집)
8. food_chips_widget.dart
9. source_badge_widget.dart
10. save_log_use_case.dart (ParseResult → DB 저장)
    - drinkLog INSERT → logId 획득
    - entries 순회 → drinkEntry INSERT (logId 연결)
    - ParseResult.foodItems → drinkLogFood 개별 row INSERT
    - parseJob.logId UPDATE (null → logId 연결)
11. 온보딩 화면 (간단 3장)

**완료 기준**: 홈에서 텍스트 입력 → 로컬 파서로 초안 생성 → 검토 화면에서 수정 → 저장 → DB에 기록 존재

### Phase 5: 기록 목록 + 아카이브 + 통계 (예상: 3~4시간)

**목표**: 저장된 기록을 보고, 수정하고, 삭제할 수 있다. 아카이브와 통계가 보인다.

태스크:
1. log_list_screen.dart (목록, 검색, 빈상태)
2. log_list_provider.dart
3. log_detail_screen.dart
4. log_edit_screen.dart (DraftReviewScreen 재사용)
5. 삭제 기능 (확인 다이얼로그 + cascade)
6. archive_screen.dart (집계 쿼리, 필터)
7. archive_provider.dart
8. archive_detail_screen.dart
9. stats_screen.dart (fl_chart 기본 차트 3개)
10. stats_provider.dart
11. 테이스팅 노트 입력 폼 (entry 상세에서)

**완료 기준**: CRUD 전체 동작, 아카이브에서 술별 누적 정보 확인, 통계 차트 표시

### Phase 6: Gemini 연동 (예상: 3~4시간)

**목표**: AI 텍스트 파싱이 동작하고, 키 관리가 된다.

태스크:
1. gemini_client.dart (dio 기반 HTTP client)
2. gemini_schemas.dart (request/response 모델)
3. gemini_config.dart (endpoint, model 상수)
4. gemini_text_parser.dart (시스템 프롬프트 + structured output)
5. parse_orchestrator.dart에 AI 파서 연결
6. ai_config_dao.dart / repository 구현
7. ai_settings_screen.dart
8. ai_settings_provider.dart
9. validate_api_key_use_case.dart (키 검증: 간단한 test 호출)
10. secure storage 연동 (키 저장/조회/삭제)
11. 앱 기본 키 주입 (`--dart-define`)

**완료 기준**: 사용자 키 등록 → 모델 선택 → AI 파싱 성공 → 초안 생성 → fallback 동작

### Phase 7: 사용량 제한 (예상: 1~2시간)

**목표**: 기본 키 일일 제한이 동작하고, 사용자에게 안내된다.

태스크:
1. usage_quota_dao.dart / repository 구현
2. orchestrator에 quota 체크 연결
3. 제한 초과 시 토스트 + 로컬 파서 fallback
4. AI 설정 화면에 오늘 사용량 표시
5. 자정 리셋 로직 (dayKey 기반, 별도 타이머 불필요)

**완료 기준**: 기본 키로 11번째 텍스트 파싱 시도 시 로컬 파서 fallback + 안내 메시지

### Phase 8: 이미지 기능 (R1.5, 예상: 2~3시간)

**목표**: 사진 첨부 + AI 이미지 기반 초안 생성.

태스크:
1. image_picker 연동
2. gemini_image_parser.dart (멀티모달 호출)
3. 홈 입력 영역에 사진 첨부 버튼
4. DraftReviewScreen에 이미지 미리보기
5. drinkLog.rawImagePath에 로컬 경로 저장
6. 이미지 전용 quota 체크

**완료 기준**: 병 라벨 사진 → AI 초안 → 검토 → 저장

### Phase 9: 마무리 (예상: 2~3시간)

태스크:
1. 빈 상태(empty state) 위젯 전체 적용
2. 로딩 인디케이터 전체 적용
3. 에러 상태 처리 전체 적용
4. 엣지 케이스 QA
   - 입력 없이 저장 시도
   - 아주 긴 텍스트 입력
   - 네트워크 끊긴 상태에서 AI 시도
   - entry 0개로 만들기 시도
   - 특수문자만 입력
5. 앱 아이콘 적용
6. 스플래시 화면
7. 다크모드 테스트
8. parseJob 로그 화면 (설정 > 최근 처리 로그)

**완료 기준**: 크래시 없이 전체 플로우 동작, 빈 상태/에러 상태 처리 완료

---

## 8. 단위 변환 기준표

통계에서 "총 음주량"을 의미있게 보여주려면 단위 변환이 필요하다.

| 주종 | glass (ml) | shot (ml) | bottle (ml) | can (ml) |
|------|-----------|-----------|-------------|----------|
| whisky | 30 | 30 | 700 | - |
| highball | 350 | - | - | 350 |
| beer | 500 | - | 500 | 355 |
| wine | 150 | - | 750 | - |
| soju | 50 | 50 | 360 | - |
| makgeolli | 300 | - | 750 | - |
| sake | 180 | 30 | 720 | - |
| cocktail | 200 | - | - | - |
| other | 100 | 30 | 500 | 355 |

R1에서는 이 표를 **표시용 참고 정보**로만 사용하고, 정밀 계산은 R2로 미룬다.

---

## 9. 테스트 전략

### 9-1. 필수 테스트 (R1)

| 대상 | 종류 | 최소 케이스 |
|------|------|-------------|
| LocalRuleParser | 단위 | 15개 입력 패턴 |
| 수량/단위 추출 | 단위 | 10개 |
| 주류명 매칭 | 단위 | 10개 (exact + alias + partial + miss) |
| 날짜 유틸 (6시 컷오프) | 단위 | 5개 |
| DAO CRUD | 통합 | 각 테이블 CRUD 4개씩 |
| ParseOrchestrator fallback | 단위 | 3개 (AI 성공, AI 실패→로컬, AI 불가→로컬) |
| Gemini response 파싱 | 단위 | 3개 (정상, 스키마 불일치, 빈 응답) |

### 9-2. 수동 QA 시나리오

1. 첫 실행 → 온보딩 → 홈
2. 텍스트 입력 → 로컬 파서 초안 → 수정 → 저장 → 목록에서 확인
3. AI 키 등록 → 텍스트 입력 → AI 초안 → 수정 → 저장
4. AI 키 삭제 → 텍스트 입력 → 로컬 파서 fallback 확인
5. 기본 키 10회 초과 → 제한 메시지 + 로컬 fallback
6. 기록 수정 → 변경 사항 반영 확인
7. 기록 삭제 → 목록/아카이브/통계 갱신 확인
8. 아카이브에서 술 검색 → 상세 → 테이스팅 노트 작성
9. 통계 화면 차트 표시 확인
10. 다크모드 전환

---

## 10. 리스크 및 대응

| 리스크 | 확률 | 영향 | 대응 |
|--------|------|------|------|
| 로컬 파서 정확도 부족 | 높음 | 중간 | 사용자 검토 필수이므로 치명적이지 않음. confidence + warnings로 보완 |
| Gemini API 키 노출 | 중간 | 높음 | 기본 키는 `--dart-define`으로 주입, 사용자 키는 secure storage |
| 시드 데이터 부족 | 중간 | 낮음 | 사용자가 검토 시 수동 매칭하면 alias 학습. 점진적 보완 |
| 일정 부족 | 높음 | 높음 | Phase 1~5 우선 완성 (로컬만으로 동작). Phase 6~8은 시간 따라 |
| Gemini structured output 실패 | 낮음 | 중간 | 로컬 파서 fallback 필수 구현 |
| 한글 정규식 엣지 케이스 | 높음 | 낮음 | 파서가 실패해도 빈 초안 + 경고로 graceful degradation |

---

## 11. 결정 로그

구현 중 임의로 확정한 사항은 여기에 기록한다.

| 날짜 | 결정 | 이유 |
|------|------|------|
| 2026-03-29 | food/place를 drinkLog 레벨로 이동 | 세션 단위 데이터이지 잔 단위가 아님 |
| 2026-03-29 | 기본 키 텍스트 일 10회, 이미지 일 3회 | 과제 시연용 적정량. 비용 통제 |
| 2026-03-29 | 6시 컷오프 기본 적용 | 새벽 음주 기록 시 전날로 분류하는 게 자연스러움 |
| 2026-03-29 | BottomNav 3탭 구조 | 홈/기록/더보기. 탭 수 최소화 원칙 |
| 2026-03-29 | Riverpod AsyncNotifier 패턴 | DB 비동기 접근에 적합 |
| 2026-03-29 | drinkEntry에서 tastingNote 1:1 관계 | 선택적 첨부. entry당 최대 1개 |

---

## 부록 A. Claude Code 마스터 프롬프트

Phase 1 착수 시 Claude Code에 투입할 프롬프트:

```
너는 Flutter 앱 "알비(Albi)"의 시니어 개발자다.

이 프로젝트의 상세 기술 계획서는 docs/PLAN.md에 있다.
모든 구현은 이 계획서를 기준으로 한다. 계획서에 없는 기능을 임의로 추가하지 마라.

현재 단계: Phase {N}
목표: {Phase 목표}
태스크: {Phase 태스크 목록}

지켜야 할 원칙:
1. 저장 전 반드시 검토/수정 화면을 거칠 것
2. AI 로직을 UI에 직접 넣지 말 것 — parser adapter 뒤로 격리
3. AI가 없어도 동작해야 한다
4. failure path first — 정상보다 비정상 복구가 더 중요
5. 과도한 추상화 금지. 실제 실행 가능한 코드 우선
6. TODO를 남길 때는 이유와 막힌 지점을 명확히 쓸 것

작업 후 보고 형식:
- 변경된 파일 목록
- 핵심 결정 사항 (계획서에 없던 판단)
- 다음 단계에서 필요한 사항
```
