import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../domain/entities/liquor_master.dart';
import '../../../integrations/parser/parse_result.dart';

/// liquorMaster 조회 FutureProvider — 검토 화면 Entry 카드에서 매칭 상태 확인.
final _entryDraftMasterProvider =
    FutureProvider.family<LiquorMaster?, int>((ref, masterId) async {
  return ref.watch(liquorMasterRepoProvider).getById(masterId);
});

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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.entry.liquorNameRaw);
    _ageCtrl = TextEditingController(text: widget.entry.ageStatement ?? '');
    _qtyCtrl = TextEditingController(
        text: widget.entry.quantityValue % 1 == 0
            ? widget.entry.quantityValue.toInt().toString()
            : widget.entry.quantityValue.toString());
    _abvCtrl = TextEditingController(
        text: widget.entry.alcoholPercent?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _qtyCtrl.dispose();
    _abvCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(widget.entry.copyWith(
      liquorNameRaw: _nameCtrl.text,
      ageStatement: _ageCtrl.text.isEmpty ? null : _ageCtrl.text,
      quantityValue: double.tryParse(_qtyCtrl.text) ?? 1.0,
      alcoholPercent:
          _abvCtrl.text.isEmpty ? null : double.tryParse(_abvCtrl.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.lowConfidence
        ? Colors.orange.shade300
        : Theme.of(context).colorScheme.outlineVariant;

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
                Text('항목 ${widget.index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (widget.canDelete)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.onDelete,
                    visualDensity: VisualDensity.compact,
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
                        .map((e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        widget.onChanged(
                            widget.entry.copyWith(liquorCategory: v));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _ageCtrl,
                    decoration: const InputDecoration(labelText: '연산'),
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 수량 + 단위 + 도수
            Row(
              children: [
                SizedBox(
                  width: 60,
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
                        .map((e) =>
                            DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        widget
                            .onChanged(widget.entry.copyWith(quantityUnit: v));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _abvCtrl,
                    decoration: const InputDecoration(labelText: '도수%'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _emit(),
                  ),
                ),
              ],
            ),
            if (widget.entry.isEstimated)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('⚠ 수량이 추정치입니다',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.orange.shade700)),
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
        ? ref.watch(_entryDraftMasterProvider(masterId))
        : null;
    final master = masterAsync?.valueOrNull;
    final rawFilled = _nameCtrl.text.trim().isNotEmpty;

    Widget? suffix;
    String? helper;
    Color? helperColor;

    if (master != null) {
      suffix = Icon(Icons.check_circle,
          size: 18, color: Colors.green.shade600);
      if (master.canonicalName != _nameCtrl.text.trim()) {
        helper = '(${master.canonicalName})';
      }
    } else if (rawFilled) {
      // master 매칭 실패 + 이름 입력됨
      suffix = Icon(Icons.warning_amber_rounded,
          size: 18, color: Colors.orange.shade700);
      helper = '⚠ 이름을 정확히 확인하지 못했습니다';
      helperColor = Colors.orange.shade700;
    }

    return TextField(
      controller: _nameCtrl,
      decoration: InputDecoration(
        labelText: '술 이름',
        suffixIcon: suffix,
        helperText: helper,
        helperStyle: helperColor != null
            ? TextStyle(color: helperColor, fontSize: 11)
            : null,
        helperMaxLines: 2,
      ),
      onChanged: (_) => _emit(),
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
