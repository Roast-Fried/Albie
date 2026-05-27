import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../integrations/parser/parse_result.dart';
import '../../../viewmodels/draft_review_viewmodel.dart';

class EntryCardWidget extends ConsumerStatefulWidget {
  final int index;
  final DraftEntry entry;
  final bool canDelete;
  final bool lowConfidence;
  final ValueChanged<DraftEntry> onChanged;
  final VoidCallback onDelete;

  const EntryCardWidget({
    super.key,
    required this.index,
    required this.entry,
    required this.canDelete,
    required this.lowConfidence,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  ConsumerState<EntryCardWidget> createState() => _EntryCardWidgetState();
}

class _EntryCardWidgetState extends ConsumerState<EntryCardWidget> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _abvCtrl;

  // 2026-05-27 Sprint 1 UI-017: 이름 변경 debounce — 매 키 입력마다 DB 조회 방지.
  String _lastMatchedName = '';
  Timer? _nameDebounce;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.entry.liquorNameRaw);
    _ageCtrl = TextEditingController(text: widget.entry.ageStatement ?? '');
    _qtyCtrl = TextEditingController(
      text: widget.entry.quantityValue % 1 == 0
          ? widget.entry.quantityValue.toInt().toString()
          : widget.entry.quantityValue.toString(),
    );
    _abvCtrl = TextEditingController(
      text: widget.entry.alcoholPercent?.toString() ?? '',
    );
    _lastMatchedName = widget.entry.liquorNameRaw.trim();
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _qtyCtrl.dispose();
    _abvCtrl.dispose();
    super.dispose();
  }

  /// 2026-05-27 Sprint 1 UI-017: 이름 변경 시 master 매칭 시도 (400ms debounce).
  /// Codex audit Finding 3.4: 이름이 length<2 가 되는 순간 _lastMatchedName 을
  /// reset 해 사용자가 같은 이름을 다시 입력해도 매칭이 동작하도록 함.
  void _scheduleNameMatch() {
    _nameDebounce?.cancel();
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      _lastMatchedName = '';
      return;
    }
    if (name == _lastMatchedName) return;
    _nameDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      // Finding 1.3: timer 발화 시점에 사용자가 다시 다른 이름을 입력했을 수 있음.
      if (_nameCtrl.text.trim() != name) return;
      _lastMatchedName = name;
      await ref
          .read(draftReviewProvider.notifier)
          .tryMatchByName(ref, widget.index, name);
    });
  }

  void _emit() {
    // Round 5 Codex Finding 5.1 — silent fallback (?? 1.0) 위험. 음수/0/100% 초과 거부.
    final parsedQty = double.tryParse(_qtyCtrl.text);
    final qty = (parsedQty != null && parsedQty > 0) ? parsedQty : 1.0;
    final parsedAbv =
        _abvCtrl.text.isEmpty ? null : double.tryParse(_abvCtrl.text);
    final abv = (parsedAbv != null && parsedAbv >= 0 && parsedAbv <= 100)
        ? parsedAbv
        : null;

    widget.onChanged(
      widget.entry.copyWith(
        liquorNameRaw: _nameCtrl.text,
        ageStatement: _ageCtrl.text.isEmpty ? null : _ageCtrl.text,
        quantityValue: qty,
        alcoholPercent: abv,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // lowConfidence 시 tertiary (warm warning) 사용 — error 만큼 강하지 않은
    // semantic. Theme token 으로 dark 모드 일관성 확보.
    final scheme = Theme.of(context).colorScheme;
    final borderColor =
        widget.lowConfidence ? scheme.tertiary : scheme.outlineVariant;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Text(
                  '항목 ${widget.index + 1}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.canDelete)
                  // tap target 48dp 보장 (음주 후 사용 시나리오 — Round 6 P1 fix)
                  IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    tooltip: '항목 삭제',
                    onPressed: widget.onDelete,
                  ),
              ],
            ),

            // 술 이름 — 매칭 아이콘 + 영문 병기/경고 helperText
            _buildNameField(context),
            const SizedBox(height: 8),

            // 주종 + 연산
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.entry.liquorCategory,
                    decoration: const InputDecoration(labelText: '주종'),
                    items: _categories.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        widget.onChanged(
                          widget.entry.copyWith(liquorCategory: v),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _ageCtrl,
                    decoration: const InputDecoration(
                      labelText: '숙성',
                      hintText: '12년',
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 2026-05-27 Sprint 1 UI-001: 360px portrait 에서 5필드 cramped.
            // 양 + 단위 + 도수% 를 2 행 분리 — 행 1: 양/단위, 행 2: 도수%.
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(labelText: '양'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.entry.quantityUnit,
                    decoration: const InputDecoration(labelText: '단위'),
                    items: _units.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        widget.onChanged(
                          widget.entry.copyWith(quantityUnit: v),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _abvCtrl,
              decoration: const InputDecoration(
                labelText: '도수 (%)',
                hintText: '예: 40',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) => _emit(),
            ),
            if (widget.entry.isEstimated)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  '⚠ 수량이 추정치입니다',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 이름 필드 — 매칭 상태 아이콘 + helperText (영문 병기 / 경고).
  Widget _buildNameField(BuildContext context) {
    final masterId = widget.entry.liquorMasterId;
    final masterAsync = masterId != null
        ? ref.watch(entryDraftMasterProvider(masterId))
        : null;
    final master = masterAsync?.valueOrNull;
    final rawFilled = _nameCtrl.text.trim().isNotEmpty;

    Widget? suffix;
    String? helper;
    Color? helperColor;

    final scheme = Theme.of(context).colorScheme;
    if (master != null) {
      // 매칭 성공 — primary (brand) 로 표현 (green 의 의미와 동등하나 token 통일)
      suffix = Icon(Icons.check_circle, size: 18, color: scheme.primary);
      if (master.canonicalName != _nameCtrl.text.trim()) {
        helper = '(${master.canonicalName})';
      }
    } else if (rawFilled) {
      // master 매칭 실패 + 이름 입력됨 — tertiary (mild warning)
      suffix = Icon(
        Icons.warning_amber_rounded,
        size: 18,
        color: scheme.tertiary,
      );
      helper = '⚠ 이름을 정확히 확인하지 못했습니다';
      helperColor = scheme.tertiary;
    }

    return TextField(
      controller: _nameCtrl,
      decoration: InputDecoration(
        labelText: '술 이름',
        suffixIcon: suffix,
        helperText: helper,
        helperStyle: helperColor != null
            ? Theme.of(context).textTheme.labelSmall?.copyWith(color: helperColor)
            : null,
        helperMaxLines: 2,
      ),
      onChanged: (_) {
        _emit();
        _scheduleNameMatch();
      },
    );
  }

  static const _categories = {
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

  static const _units = {
    'glass': '잔',
    'shot': '샷',
    'bottle': '병',
    'can': '캔',
    'ml': 'ml',
    'unknown': '모름',
  };
}
