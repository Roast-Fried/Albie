import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../integrations/drift_demo/condition_database.dart';
import '../../viewmodels/condition_log_viewmodel.dart';
import '../common/delete_confirm_dialog.dart';

/// 컨디션 로그 화면 — Drift 격리 데모.
///
/// 강의 기법 시연:
/// - **Drift watch()** → **StreamBuilder** 로 reactive 목록 (쓰기 시 자동 갱신)
/// - **FutureBuilder** + `setState` 로 평균 숙취도 one-shot 재조회 (강의 패턴)
/// - **StatefulWidget lifecycle** (initState)
///
/// View 는 ConditionLogViewModel 메서드만 호출 (DB/DAO 직접 접근 금지).
class ConditionLogScreen extends ConsumerStatefulWidget {
  const ConditionLogScreen({super.key});

  @override
  ConsumerState<ConditionLogScreen> createState() => _ConditionLogScreenState();
}

class _ConditionLogScreenState extends ConsumerState<ConditionLogScreen> {
  late Future<double> _avgFuture;
  late final Stream<List<ConditionLog>> _logsStream;

  @override
  void initState() {
    super.initState();
    final vm = ref.read(conditionLogViewModelProvider);
    // 강의 FutureBuilder 패턴: initState 에서 Future 를 1회 안정화.
    _avgFuture = vm.avgSeverityOnce();
    // watch stream 도 initState 에서 1회 생성 — build 마다 재구독 방지.
    _logsStream = vm.watchLogs();
  }

  /// 쓰기 후 평균 Future 재실행 — 강의 "setState 로 FutureBuilder 재빌드" 시연.
  void _refreshAvg() {
    setState(() {
      _avgFuture = ref.read(conditionLogViewModelProvider).avgSeverityOnce();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('컨디션 로그')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('condition_add'),
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('기록'),
      ),
      body: Column(
        children: [
          _AvgSeverityCard(future: _avgFuture),
          const Divider(height: 1),
          Expanded(
            // 강의 watch()+StreamBuilder: Drift 쓰기 시 자동 emit → 목록 자동 갱신.
            child: StreamBuilder<List<ConditionLog>>(
              stream: _logsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('불러오기 오류: ${snapshot.error}'));
                }
                final logs = snapshot.data ?? const [];
                if (logs.isEmpty) {
                  return const Center(
                    child: Text('아직 컨디션 기록이 없어요.\n+ 버튼으로 추가하세요.',
                        textAlign: TextAlign.center),
                  );
                }
                return ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, i) =>
                      _ConditionTile(log: logs[i], onDeleted: _refreshAvg),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ConditionEditor(),
    );
    if (saved == true) _refreshAvg();
  }
}

/// 평균 숙취도 카드 — FutureBuilder 시연 (connectionState/hasData/hasError).
class _AvgSeverityCard extends StatelessWidget {
  const _AvgSeverityCard({required this.future});

  final Future<double> future;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<double>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text('평균 숙취도 계산 중…');
              }
              if (snapshot.hasError) {
                return Text('평균 계산 오류: ${snapshot.error}');
              }
              final avg = snapshot.data ?? 0;
              return Row(
                children: [
                  Icon(Icons.monitor_heart_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text('평균 숙취도  ${avg.toStringAsFixed(1)} / 5',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConditionTile extends ConsumerWidget {
  const _ConditionTile({required this.log, required this.onDeleted});

  final ConditionLog log;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('M월 d일 (E)', 'ko_KR');
    final sub = [
      if (log.sleepHours != null) '수면 ${log.sleepHours!.toStringAsFixed(1)}h',
      if (log.memo != null && log.memo!.isNotEmpty) log.memo!,
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(child: Text('${log.severity}')),
      title: Text('${df.format(log.loggedOn)}  숙취 ${log.severity}/5'),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: '삭제',
        onPressed: () async {
          final ok = await showDeleteConfirmDialog(
            context,
            title: '컨디션 기록 삭제',
            content: '이 컨디션 기록을 삭제할까요?',
          );
          if (ok == true) {
            try {
              await ref.read(conditionLogViewModelProvider).remove(log.id);
              onDeleted();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('삭제 중 오류가 발생했어요')),
                );
              }
            }
          }
        },
      ),
    );
  }
}

/// 입력 바텀시트 — 숙취도(1~5) + 수면시간 + 메모.
class _ConditionEditor extends ConsumerStatefulWidget {
  const _ConditionEditor();

  @override
  ConsumerState<_ConditionEditor> createState() => _ConditionEditorState();
}

class _ConditionEditorState extends ConsumerState<_ConditionEditor> {
  int _severity = 3;
  final _sleepController = TextEditingController();
  final _memoController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _sleepController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('오늘의 컨디션', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Text('숙취 정도'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$i'),
                    selected: _severity == i,
                    onSelected: (_) => setState(() => _severity = i),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sleepController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '수면 시간 (선택, 예: 6.5)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memoController,
            decoration: const InputDecoration(labelText: '메모 (선택)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('condition_save'),
              onPressed: _saving ? null : _save,
              child: const Text('저장'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    // 수면시간 입력 검증 — 비어있으면 생략, 입력했으면 0~24 유효값만 허용.
    final sleepText = _sleepController.text.trim();
    double? sleep;
    if (sleepText.isNotEmpty) {
      final parsed = double.tryParse(sleepText);
      if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수면 시간은 0~24 사이 숫자로 입력하세요')),
        );
        return;
      }
      sleep = parsed;
    }

    setState(() => _saving = true);
    final memo = _memoController.text.trim();
    try {
      await ref.read(conditionLogViewModelProvider).add(
            loggedOn: DateTime.now(),
            severity: _severity,
            sleepHours: sleep,
            memo: memo.isEmpty ? null : memo,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 중 오류가 발생했어요')),
        );
      }
    }
  }
}
