/// Gemini structured output response schema
const geminiParseResponseSchema = {
  'type': 'OBJECT',
  'properties': {
    'confidence': {'type': 'NUMBER'},
    'parseWarnings': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'}
    },
    'drankAt': {'type': 'STRING', 'nullable': true},
    'place': {'type': 'STRING', 'nullable': true},
    'overallMemo': {'type': 'STRING', 'nullable': true},
    'foodItems': {
      'type': 'ARRAY',
      'items': {'type': 'STRING'}
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
              'whisky', 'highball', 'beer', 'wine', 'cocktail',
              'soju', 'makgeolli', 'sake', 'other'
            ]
          },
          'ageStatement': {'type': 'STRING', 'nullable': true},
          'quantityValue': {'type': 'NUMBER'},
          'quantityUnit': {
            'type': 'STRING',
            'enum': ['glass', 'shot', 'bottle', 'can', 'ml', 'unknown']
          },
          'isEstimated': {'type': 'BOOLEAN'},
          'alcoholPercent': {'type': 'NUMBER', 'nullable': true},
        },
        'required': [
          'liquorCategory', 'quantityValue', 'quantityUnit', 'isEstimated'
        ]
      }
    }
  },
  'required': ['confidence', 'parseWarnings', 'entries', 'foodItems']
};

/// 시스템 프롬프트 생성
String buildSystemPrompt(DateTime now) {
  final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  return '''너는 음주 기록 파서다. 사용자가 입력한 자연어 문장에서 음주 정보를 추출해 JSON으로 반환한다.

규칙:
1. entries는 1개 이상 반환한다.
2. 확실하지 않은 필드는 null로 둔다.
3. 양을 모르면 quantityValue=1, quantityUnit="unknown", isEstimated=true로 설정한다.
4. 술 종류를 모르면 liquorCategory="other"로 설정한다.
5. "어제", "그저께" 등 상대 날짜는 현재 날짜 기준으로 ISO-8601 절대 날짜로 변환한다. 현재 날짜: $dateStr
6. 00:00~05:59 사이라면 전날로 간주한다.
7. 건강, 의학, 체내 알코올 관련 내용은 무시한다.
8. 확신도가 낮은 항목은 parseWarnings에 이유를 적는다.
9. ageStatement는 "15년" 형태로 한글 단위를 포함한다.''';
}
