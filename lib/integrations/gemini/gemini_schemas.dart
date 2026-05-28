/// Gemini structured output response schema
const geminiParseResponseSchema = {
  'type': 'OBJECT',
  'properties': {
    'confidence': {'type': 'NUMBER'},
    'parseWarnings': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'},
    },
    'drankAt': {'type': 'STRING', 'nullable': true},
    'place': {'type': 'STRING', 'nullable': true},
    'overallMemo': {'type': 'STRING', 'nullable': true},
    'foodItems': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'},
    },
    'entries': {
      'type': 'ARRAY',
      'items': {
        'type': 'OBJECT',
        'properties': {
          'liquorName': {'type': 'STRING', 'nullable': true},
          'liquorCategory': {
            'type': 'STRING',
            'enum': [
              'whisky',
              'highball',
              'beer',
              'wine',
              'cocktail',
              'soju',
              'makgeolli',
              'sake',
              'other',
            ],
          },
          'ageStatement': {'type': 'STRING', 'nullable': true},
          'quantityValue': {'type': 'NUMBER'},
          'quantityUnit': {
            'type': 'STRING',
            'enum': ['glass', 'shot', 'bottle', 'can', 'ml', 'unknown'],
          },
          'isEstimated': {'type': 'BOOLEAN'},
          'alcoholPercent': {'type': 'NUMBER', 'nullable': true},
        },
        'required': [
          'liquorName',
          'liquorCategory',
          'quantityValue',
          'quantityUnit',
          'isEstimated',
        ],
      },
    },
  },
  'required': ['confidence', 'parseWarnings', 'entries', 'foodItems'],
};

const geminiTastingNoteResponseSchema = {
  'type': 'OBJECT',
  'properties': {
    'nose': {'type': 'STRING', 'nullable': true},
    'palate': {'type': 'STRING', 'nullable': true},
    'finish': {'type': 'STRING', 'nullable': true},
    'note': {'type': 'STRING', 'nullable': true},
  },
};

/// 시스템 프롬프트 생성
String buildSystemPrompt(
  DateTime now, {
  String defaultQuantityUnit = 'unknown',
  bool sixHourCutoffEnabled = true,
}) {
  final dateStr =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final unknownQuantityRule =
      '양을 모르면 quantityValue=1, quantityUnit="$defaultQuantityUnit", isEstimated=true로 설정한다.';
  final cutoffRule = sixHourCutoffEnabled
      ? '00:00~05:59 사이라면 전날로 간주한다.'
      : '00:00~05:59 입력도 같은 날짜로 유지한다.';

  return '''너는 음주 기록 파서다. 사용자가 입력한 자연어 문장에서 음주 정보를 추출해 JSON으로 반환한다.

규칙:
1. entries는 1개 이상 반환한다.
2. 확실하지 않은 필드는 null로 둔다. 단 liquorName 은 모르면 빈 문자열이 아닌 null 로 둔다 (필드 자체는 항상 응답에 포함한다).
3. $unknownQuantityRule
4. 술 종류를 모르면 liquorCategory="other"로 설정한다.
5. "어제", "그저께" 등 상대 날짜는 현재 날짜 기준으로 ISO-8601 절대 날짜로 변환한다. 현재 날짜: $dateStr
6. $cutoffRule
7. 건강, 의학, 체내 알코올 관련 내용은 무시한다.
8. 확신도가 낮은 항목은 parseWarnings에 이유를 적는다.
9. ageStatement는 "15년" 형태로 한글 단위를 포함한다.
10. 사람/모임/장소/감정 단어 (친구들, 친구, 가족, 동료, 혼자, 같이, 함께, 회식, 모임, 집, 술집, 바, 클럽, 좋아서, 기분, 신나서 등) 는 술 이름으로 분류하지 않는다. 술 이름이 명시되지 않으면 liquorName=null + liquorCategory="other" 로 둔다.''';
}

String buildTastingNoteSystemPrompt() {
  return '''너는 위스키와 주류 테이스팅 노트를 정리하는 편집 보조다.

규칙:
1. 사용자가 쓴 단서를 과장하지 말고 자연스럽고 짧은 한국어로 정리한다.
2. nose, palate, finish는 비어있으면 null로 둘 수 있다.
3. note는 한 줄 감상으로 40자 이내를 권장한다.
4. 의학, 건강, 음주 권장 표현은 만들지 않는다.
5. JSON 스키마에 맞춰서만 반환한다.''';
}
