import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/log_list_viewmodel.dart';
import '../../domain/entities/drink_log.dart';
import 'log_detail_screen.dart';

class LogListScreen extends ConsumerStatefulWidget {
  const LogListScreen({super.key});

  @override
  ConsumerState<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends ConsumerState<LogListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logListProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '검색...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) =>
                    ref.read(logListProvider.notifier).search(v),
              )
            : const Text('기록'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchCtrl.clear();
                  ref.read(logListProvider.notifier).refresh();
                }
              });
            },
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (logs) => logs.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () => ref.read(logListProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _LogTile(
                    log: logs[i],
                    onTap: () => _openDetail(context, logs[i]),
                    onDelete: () => _confirmDelete(context, ref, logs[i]),
                  ),
                ),
              ),
      ),
    );
  }

  void _openDetail(BuildContext context, DrinkLog log) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => LogDetailScreen(logId: log.id!),
        ))
        .then((_) => ref.read(logListProvider.notifier).refresh());
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DrinkLog log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(logListProvider.notifier).delete(log.id!);
            },
            child: Text('삭제',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final DrinkLog log;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _LogTile(
      {required this.log, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M/d (E) a h:mm', 'ko').format(log.drankAt);
    final summary = log.entries
        .map((e) =>
            '${e.liquorNameRaw} ${e.quantityValue % 1 == 0 ? e.quantityValue.toInt() : e.quantityValue}${_unitLabel(e.quantityUnit)}')
        .join(', ');

    return Card(
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 4),
              Text(summary.isEmpty ? '(항목 없음)' : summary,
                  style: Theme.of(context).textTheme.bodyMedium),
              if (log.foodItems.isNotEmpty || log.place != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (log.foodItems.isNotEmpty)
                      Text('🍽 ${log.foodItems.join(", ")}',
                          style: Theme.of(context).textTheme.bodySmall),
                    if (log.foodItems.isNotEmpty && log.place != null)
                      const SizedBox(width: 8),
                    if (log.place != null)
                      Text('📍 ${log.place}',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _unitLabel(String unit) {
    const map = {
      'glass': '잔', 'shot': '샷', 'bottle': '병',
      'can': '캔', 'ml': 'ml', 'unknown': '',
    };
    return map[unit] ?? '';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notes_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('아직 기록이 없어요'),
        ],
      ),
    );
  }
}
