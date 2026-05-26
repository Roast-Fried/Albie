import 'dart:convert';
import 'package:flutter/services.dart';
import '../../data/liquor_master_repository.dart';
import '../../core/utils/korean_number.dart';
import '../../core/utils/date_utils.dart';
import 'parse_result.dart';

class LocalRuleParser {
  final LiquorMasterRepository _liquorRepo;
  final String defaultQuantityUnit;
  final bool sixHourCutoffEnabled;
  List<Map<String, dynamic>>? _foodDict;
  Map<String, dynamic>? _placeKeywords;

  LocalRuleParser(
    this._liquorRepo, {
    this.defaultQuantityUnit = 'glass',
    this.sixHourCutoffEnabled = true,
  });

  Future<ParseResult> parse(ParseInput input) async {
    await _ensureDictsLoaded();

    final text = input.text.trim();
    if (text.isEmpty) {
      return ParseResult.empty(warnings: ['입력이 비어있습니다']);
    }

    final warnings = <String>[];

    // 1. 날짜 추출
    final drankAt =
        parseRelativeDate(
          text,
          input.inputTime,
          sixHourCutoffEnabled: sixHourCutoffEnabled,
        ) ??
        applySixHourCutoff(input.inputTime, enabled: sixHourCutoffEnabled);

    // 2. 장소 추출
    final place = _extractPlace(text);

    // 3. 음식 추출
    final foods = _extractFoods(text);

    // 4. 항목 분리 + 파싱
    final segments = _splitSegments(text);
    final entries = <DraftEntry>[];

    for (final seg in segments) {
      final entry = await _parseSegment(seg, warnings);
      if (entry != null) entries.add(entry);
    }

    // 아무것도 못 뽑았으면 기본 entry
    if (entries.isEmpty) {
      warnings.add('술 정보를 추출하지 못했습니다. 직접 입력해주세요.');
      entries.add(
        DraftEntry(
          liquorNameRaw: text,
          liquorCategory: 'other',
          isEstimated: true,
          quantityUnit: 'unknown',
        ),
      );
    }

    final confidence = _calcConfidence(entries, place, foods, warnings);

    return ParseResult(
      source: 'local_parser',
      confidence: confidence,
      parseWarnings: warnings,
      entries: entries,
      foodItems: foods,
      place: place,
      drankAt: drankAt,
    );
  }

  // --- Segment splitting ---

  // 다중 음주 분리용 술 카테고리 키워드
  static const _drinkSplitKeywords = [
    '소주', '맥주', '위스키', '와인', '하이볼', '막걸리', '사케', '칵테일', '소맥',
  ];

  /// "글렌피딕 한 잔이랑 맥주 두 캔" → ["글렌피딕 한 잔", "맥주 두 캔"]
  /// 접속사 없어도 카테고리 키워드 2회 + 수량 패턴 등장 시 분리
  List<String> _splitSegments(String text) {
    // 접속사/구분자로 분리
    final parts = text
        .replaceAll(RegExp(r'이랑|하고|그리고|에다가?|,|，'), '||')
        .split('||')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (parts.isEmpty) return [text];

    // 접속사 없는 다중 음주 분리: "소주 2병 맥주 3잔" 같은 경우
    final result = <String>[];
    for (final part in parts) {
      result.addAll(_splitByDrinkKeyword(part));
    }
    return result;
  }

  /// 단일 세그먼트 안에 술 카테고리 키워드가 2회 이상 + 각 키워드 뒤에 수량 패턴이 있으면 분리.
  /// "맥주집에서" 같은 false positive 방지:
  ///   키워드 바로 뒤 문자가 한글이면 복합어로 간주해 분리 금지.
  List<String> _splitByDrinkKeyword(String text) {
    // 수량 패턴: 숫자+단위 또는 한글 수량어 (_extractQuantity 와 동일 범위 유지)
    final qtyPattern = RegExp(
      r'\d+(?:\.\d+)?\s*(?:잔|병|캔|샷|ml|미리|모금|개|컵|파인트)'
      r'|(?:한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|열한|열두|반)\s*(?:잔|병|캔|샷|모금|개|컵)'
      r'|반\s*(?:병|잔)',
    );

    // 각 카테고리 키워드의 위치 찾기
    final hits = <({int start, int end, String kw})>[];
    for (final kw in _drinkSplitKeywords) {
      int searchFrom = 0;
      while (searchFrom < text.length) {
        final idx = text.indexOf(kw, searchFrom);
        if (idx < 0) break;
        final afterIdx = idx + kw.length;
        // 키워드 뒤 문자가 한글이면 복합어 — 분리 금지
        if (afterIdx < text.length) {
          final nextChar = text[afterIdx];
          final isKorean = RegExp(r'[가-힣]').hasMatch(nextChar);
          if (isKorean) {
            searchFrom = afterIdx;
            continue;
          }
        }
        hits.add((start: idx, end: afterIdx, kw: kw));
        searchFrom = afterIdx;
      }
    }

    // 위치 순 정렬
    hits.sort((a, b) => a.start.compareTo(b.start));

    // 2개 이상의 hit 가 있고 각각 뒤에 수량 패턴이 있는지 확인
    if (hits.length < 2) return [text];

    // 각 hit 에 수량 패턴이 근접(30자 이내)해 있는지 확인
    final validHits = hits.where((h) {
      final tail = text.substring(h.start, (h.start + 30).clamp(0, text.length));
      return qtyPattern.hasMatch(tail);
    }).toList();

    if (validHits.length < 2) return [text];

    // 첫 번째 hit 의 시작 위치에서 분리
    // 두 번째 hit 의 시작 바로 앞에서 split
    final splitAt = validHits[1].start;
    final first = text.substring(0, splitAt).trim();
    final rest = text.substring(splitAt).trim();
    if (first.isEmpty || rest.isEmpty) return [text];

    // 재귀적으로 rest 도 분리 시도
    return [first, ..._splitByDrinkKeyword(rest)];
  }

  // --- Per-segment parsing ---

  Future<DraftEntry?> _parseSegment(String seg, List<String> warnings) async {
    // 음식/장소/시간 전용 세그먼트면 skip
    if (_isNonDrinkSegment(seg)) return null;

    // 수량 + 단위 추출
    final qty = _extractQuantity(seg);

    // 주류명 매칭
    final match = await _matchLiquor(seg, warnings);

    // age statement 추출
    final age = _extractAge(seg);

    // 명시 도수 추출 ("40%", "17도", "도수 43" 등) — 마스터의 defaultAbv 보다 우선.
    final explicitAbv = _extractAbv(seg);

    // 주종 추론
    final category = match?.category ?? _inferCategory(seg) ?? 'other';

    final liquorNameRaw =
        match?.nameKo ?? match?.canonicalName ?? _extractLiquorToken(seg);

    return DraftEntry(
      liquorName: match?.nameKo ?? match?.canonicalName,
      liquorMasterId: match?.id,
      liquorNameRaw: liquorNameRaw,
      liquorCategory: category,
      ageStatement: age,
      quantityValue: qty?.value ?? 1.0,
      quantityUnit: qty?.unit ?? defaultQuantityUnit,
      isEstimated: qty == null,
      alcoholPercent: explicitAbv ?? match?.defaultAbv,
    );
  }

  /// 입력 텍스트에서 명시 도수를 추출한다.
  /// 매칭 예: "40%", "40 %", "17도", "도수 43", "abv 5.5"
  /// 범위: 0 < abv <= 96 (96 = 95% 이상의 spirits 상한, 100 은 비현실)
  /// 매칭 실패 또는 범위 밖이면 null → 호출자가 master defaultAbv 로 fallback.
  double? _extractAbv(String text) {
    // 패턴 A: "40%", "5.5 %"
    final percent = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(text);
    if (percent != null) {
      final v = double.tryParse(percent.group(1)!);
      if (v != null && v > 0 && v <= 96) return v;
    }

    // 패턴 B: "17도", "도수 43", "도수: 43", "abv 5.5"
    // "도" 는 "년도" 와 충돌 가능 → 앞뒤 컨텍스트로 분리
    final doSuffix = RegExp(r'(\d+(?:\.\d+)?)\s*도(?![수가년])').firstMatch(text);
    if (doSuffix != null) {
      final v = double.tryParse(doSuffix.group(1)!);
      if (v != null && v > 0 && v <= 96) return v;
    }

    final doPrefix = RegExp(r'도수\s*[:=]?\s*(\d+(?:\.\d+)?)').firstMatch(text);
    if (doPrefix != null) {
      final v = double.tryParse(doPrefix.group(1)!);
      if (v != null && v > 0 && v <= 96) return v;
    }

    final abvPrefix =
        RegExp(r'\babv\s*[:=]?\s*(\d+(?:\.\d+)?)', caseSensitive: false)
            .firstMatch(text);
    if (abvPrefix != null) {
      final v = double.tryParse(abvPrefix.group(1)!);
      if (v != null && v > 0 && v <= 96) return v;
    }

    return null;
  }

  bool _isNonDrinkSegment(String seg) {
    // 음식만 포함된 세그먼트
    if (_foodDict == null) return false;
    final lower = seg.toLowerCase();
    // 날짜 키워드만
    if (RegExp(r'^(어제|그저께|그제|오늘|지난주)$').hasMatch(lower)) return true;
    // 음식 사전에 완전 일치
    for (final f in _foodDict!) {
      final aliases = (f['aliases'] as List).cast<String>();
      if (aliases.any((a) => a == lower)) return true;
    }
    return false;
  }

  // --- Quantity extraction ---

  _Quantity? _extractQuantity(String text) {
    // 패턴 1: "2잔", "3캔", "1병", "0.5병"
    final numUnit = RegExp(r'(\d+(?:\.\d+)?)\s*(잔|샷|병|캔|모금|개|컵|파인트)');
    final m1 = numUnit.firstMatch(text);
    if (m1 != null) {
      final val = double.tryParse(m1.group(1)!) ?? 1.0;
      final unit = mapUnit(m1.group(2)!) ?? 'glass';
      return _Quantity(val, unit);
    }

    // 패턴 2: "두 잔", "한 병", "세 캔"
    final korUnit = RegExp(
      r'(한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|열한|열두|반)\s*(잔|샷|병|캔|모금|개|컵)',
    );
    final m2 = korUnit.firstMatch(text);
    if (m2 != null) {
      final val = parseKoreanNumber(m2.group(1)!) ?? 1.0;
      final unit = mapUnit(m2.group(2)!) ?? 'glass';
      return _Quantity(val, unit);
    }

    // 패턴 3: "반 병"
    final halfUnit = RegExp(r'반\s*(병|잔)');
    final m3 = halfUnit.firstMatch(text);
    if (m3 != null) {
      final unit = mapUnit(m3.group(1)!) ?? 'bottle';
      return _Quantity(0.5, unit);
    }

    // 패턴 4: "{숫자}ml"
    final ml = RegExp(r'(\d+(?:\.\d+)?)\s*(ml|미리)');
    final m4 = ml.firstMatch(text);
    if (m4 != null) {
      return _Quantity(double.tryParse(m4.group(1)!) ?? 0, 'ml');
    }

    // "조금", "좀" → unknown
    if (text.contains('조금') || text.contains('좀')) {
      return _Quantity(1.0, 'unknown');
    }

    return null;
  }

  // --- Age statement extraction ---

  String? _extractAge(String text) {
    // "15년", "12년산"
    final ageYear = RegExp(r'(\d{1,3})\s*년(산)?');
    final m = ageYear.firstMatch(text);
    if (m != null) return '${m.group(1)}년';

    // 숫자만 단독 등장 (술 이름 바로 뒤) — "벤로막 15 두 잔"에서 15
    // 이건 liquor 매칭 후 남은 숫자로 판단
    final standalone = RegExp(r'\b(\d{1,3})\b');
    final matches = standalone.allMatches(text).toList();
    for (final m in matches) {
      final num = int.tryParse(m.group(1)!) ?? 0;
      // age statement로 그럴듯한 범위: 3~50
      if (num >= 3 && num <= 50) {
        // 수량으로 이미 매칭된 숫자인지 확인
        final qtyMatch = RegExp(r'\d+\s*(잔|샷|병|캔|ml|미리|개)').firstMatch(text);
        if (qtyMatch != null && qtyMatch.group(0)!.contains(m.group(0)!)) {
          continue;
        }
        return '$num년';
      }
    }

    return null;
  }

  // --- Liquor matching ---

  Future<_LiquorMatch?> _matchLiquor(String seg, List<String> warnings) async {
    // 텍스트에서 숫자/단위/접속사 제거 → 술 이름 후보
    final cleaned = seg
        .replaceAll(
          RegExp(r'\d+(?:\.\d+)?\s*(잔|샷|병|캔|ml|미리|개|모금|컵|년산?)\s*'),
          '',
        )
        .replaceAll(
          RegExp(r'(한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|반)\s*(잔|샷|병|캔|개|컵)\s*'),
          '',
        )
        .replaceAll(RegExp(r'(마셨어|마심|마셨는데|마셨음|먹음|먹었어|마시고|더)'), '')
        .replaceAll(RegExp(r'(어제|오늘|그저께|지난주|나|에서|좀|조금|정도)'), '')
        .trim();

    if (cleaned.isEmpty) return null;

    // 토큰별로 매칭 시도
    final tokens = cleaned.split(RegExp(r'\s+'));

    // 1단계: 전체 문자열로 exact alias 매칭
    final exact = await _liquorRepo.findByAlias(cleaned);
    if (exact != null) {
      return _LiquorMatch(
        id: exact.id,
        canonicalName: exact.canonicalName,
        nameKo: exact.nameKo,
        category: exact.category,
        defaultAbv: exact.defaultAbv,
      );
    }

    // 2단계: 토큰별 exact alias 매칭
    for (final token in tokens) {
      if (token.length < 2) continue;
      final match = await _liquorRepo.findByAlias(token);
      if (match != null) {
        return _LiquorMatch(
          id: match.id,
          canonicalName: match.canonicalName,
          nameKo: match.nameKo,
          category: match.category,
          defaultAbv: match.defaultAbv,
        );
      }
    }

    // 3단계: 부분 매칭
    for (final token in tokens) {
      if (token.length < 2) continue;
      final match = await _liquorRepo.findByPartialMatch(token);
      if (match != null) {
        return _LiquorMatch(
          id: match.id,
          canonicalName: match.canonicalName,
          nameKo: match.nameKo,
          category: match.category,
          defaultAbv: match.defaultAbv,
        );
      }
    }

    // 매칭 실패
    if (cleaned.length >= 2) {
      warnings.add('술 이름을 정확히 확인하지 못했습니다');
    }
    return null;
  }

  /// 주종 키워드로 category 추론
  String? _inferCategory(String text) {
    final lower = text.toLowerCase();
    final tokens = lower.split(RegExp(r'\s+'));
    for (final t in tokens) {
      final cat = mapCategory(t);
      if (cat != null) return cat;
    }
    // 부분 매칭
    for (final entry in {
      '위스키': 'whisky',
      '하이볼': 'highball',
      '맥주': 'beer',
      '와인': 'wine',
      '소주': 'soju',
      '막걸리': 'makgeolli',
      '칵테일': 'cocktail',
      '사케': 'sake',
    }.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// 세그먼트에서 가장 그럴듯한 술 토큰 추출
  String _extractLiquorToken(String seg) {
    final cleaned = seg
        .replaceAll(RegExp(r'\d+(?:\.\d+)?\s*(잔|샷|병|캔|ml|미리|개|모금|년산?)\s*'), '')
        .replaceAll(
          RegExp(r'(한|두|세|네|다섯|여섯|일곱|여덟|아홉|열|반)\s*(잔|샷|병|캔|개)\s*'),
          '',
        )
        .replaceAll(RegExp(r'(마셨어|마심|마셨는데|마셨음|먹음|먹었어|마시고|더)'), '')
        .replaceAll(RegExp(r'(어제|오늘|그저께|나|에서|좀|조금|정도)\s*'), '')
        .trim();
    return cleaned.isEmpty ? seg.trim() : cleaned;
  }

  // --- Food extraction ---

  /// RegExp 메타문자 이스케이프 (Dart 는 RegExp.escape 미지원)
  String _escapeRegExp(String s) {
    return s.replaceAllMapped(RegExp(r'[\^$.|?*+()[\]{}]'), (m) => '\\${m.group(0)}');
  }

  List<String> _extractFoods(String text) {
    if (_foodDict == null) return [];
    final lower = text.toLowerCase();
    final found = <String>[];

    for (final f in _foodDict!) {
      final name = f['name'] as String;
      final aliases = (f['aliases'] as List).cast<String>();
      for (final alias in aliases) {
        final a = alias.toLowerCase();
        // 단글자 alias: 한글/영문/숫자 경계 검사 (예: '회사' 안의 '회' 오탐 방지)
        // 2글자 이상: contains 그대로 (치즈랑 같은 조사 붙은 경우도 매칭)
        final bool matches;
        if (a.length == 1) {
          final escaped = _escapeRegExp(a);
          // 앞뒤에 한글/영문/숫자가 없으면 매칭 (공백/구두점/문장 경계만 허용)
          matches = RegExp(
            '(?<![가-힣A-Za-z0-9])$escaped(?![가-힣A-Za-z0-9])',
          ).hasMatch(lower);
        } else {
          matches = lower.contains(a);
        }
        if (matches) {
          if (!found.contains(name)) found.add(name);
          break;
        }
      }
    }
    return found;
  }

  // --- Place extraction ---

  // 술 카테고리 키워드 (장소 후보에서 제외)
  static const _drinkCategoryKeywords = [
    '소주', '맥주', '위스키', '와인', '하이볼', '막걸리', '사케', '칵테일', '소맥',
  ];

  String? _extractPlace(String text) {
    if (_placeKeywords == null) return null;

    // 패턴 1: exact match (highest priority)
    final exact = (_placeKeywords!['exactMatch'] as List).cast<String>();
    for (final p in exact) {
      if (text.contains(p)) return p;
    }

    // 패턴 2: 지역명
    final areas = (_placeKeywords!['areas'] as List).cast<String>();
    for (final area in areas) {
      if (text.contains(area)) return area;
    }

    // 패턴 3: 접미사 ("~바", "~펍")
    final suffixes = (_placeKeywords!['suffixes'] as List).cast<String>();
    for (final suf in suffixes) {
      final pattern = RegExp('(\\S+$suf)');
      final m = pattern.firstMatch(text);
      if (m != null) return m.group(1);
    }

    // 패턴 4: '~에서' — fallback 최후순위.
    // 후보 검증: 길이 >= 2 + 술 카테고리 키워드가 아닌 경우만 채택
    final atPattern = RegExp(r'(\S+?)에서');
    final m = atPattern.firstMatch(text);
    if (m != null) {
      final candidate = m.group(1)!;
      if (candidate.length >= 2 &&
          !_drinkCategoryKeywords.contains(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  // --- Confidence ---

  double _calcConfidence(
    List<DraftEntry> entries,
    String? place,
    List<String> foods,
    List<String> warnings,
  ) {
    var score = 0.5;
    if (entries.isNotEmpty) score += 0.1;
    if (entries.any((e) => e.liquorMasterId != null)) score += 0.15;
    if (entries.any((e) => e.quantityUnit != 'unknown')) score += 0.1;
    if (place != null) score += 0.05;
    if (foods.isNotEmpty) score += 0.05;
    if (warnings.isEmpty) score += 0.05;
    return score.clamp(0.0, 1.0);
  }

  // --- Dict loading ---

  Future<void> _ensureDictsLoaded() async {
    if (_foodDict == null) {
      try {
        final str = await rootBundle.loadString(
          'assets/seed/food_dictionary.json',
        );
        _foodDict = (jsonDecode(str) as List).cast<Map<String, dynamic>>();
      } on Exception catch (_) {
        _foodDict = [];
      }
    }
    if (_placeKeywords == null) {
      try {
        final str = await rootBundle.loadString(
          'assets/seed/place_keywords.json',
        );
        _placeKeywords = jsonDecode(str) as Map<String, dynamic>;
      } on Exception catch (_) {
        _placeKeywords = {'suffixes': [], 'exactMatch': [], 'areas': []};
      }
    }
  }
}

// --- Internal types ---

class _Quantity {
  final double value;
  final String unit;
  _Quantity(this.value, this.unit);
}

class _LiquorMatch {
  final int? id;
  final String canonicalName;
  final String? nameKo;
  final String category;
  final double? defaultAbv;

  _LiquorMatch({
    this.id,
    required this.canonicalName,
    this.nameKo,
    required this.category,
    this.defaultAbv,
  });
}
