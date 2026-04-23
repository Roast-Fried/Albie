import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/date_utils.dart' as dt_utils;
import '../../core/utils/label_utils.dart';
import '../../viewmodels/log_list_viewmodel.dart';
import '../../domain/entities/drink_log.dart';
import '../common/delete_confirm_dialog.dart';
import '../common/error_state_widget.dart';
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
        error: (e, _) => ErrorStateWidget(
            message: '기록을 불러올 수 없습니다',
            onRetry: () => ref.read(logListProvider.notifier).refresh()),
        data: (logs) => logs.isEmpty
            ? const _EmptyState()
            : RefreshIndicator(
                onRefresh: () => ref.read(logListProvider.notifier).refresh(),
                child: _buildGroupedList(context, ref, logs),
              ),
      ),
    );
  }

  /// 월별 섹션 헤더 + 로그 타일을 섞어 flat list 로 반환.
  Widget _buildGroupedList(
      BuildContext context, WidgetRef ref, List<DrinkLog> logs) {
    // 월 키 → 로그 리스트
    final sorted = [...logs]..sort((a, b) => b.drankAt.compareTo(a.drankAt));
    final items = <_ListItem>[];
    String? currentKey;
    for (final log in sorted) {
      final key =
          '${log.drankAt.year}-${log.drankAt.month.toString().padLeft(2, '0')}';
      if (key != currentKey) {
        currentKey = key;
        final label = DateFormat('y년 M월', 'ko').format(log.drankAt);
        items.add(_ListItem.header(label));
      }
      items.add(_ListItem.log(log));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (context, i) {
        final next = i + 1 < items.length ? items[i + 1] : null;
        if (next?.isHeader == true) return const SizedBox(height: 16);
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, i) {
        final it = items[i];
        if (it.isHeader) {
          return Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 4),
            child: Text(it.header!,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          );
        }
        final log = it.log!;
        return _LogTile(
          log: log,
          onTap: () => _openDetail(context, log),
          onDelete: () => _confirmDelete(context, ref, log),
        );
      },
    );
  }

  void _openDetail(BuildContext context, DrinkLog log) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => LogDetailScreen(logId: log.id!),
        ))
        .then((_) => ref.read(logListProvider.notifier).refresh());
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DrinkLog log) async {
    final confirmed = await showDeleteConfirmDialog(context);
    if (confirmed == true) {
      await ref.read(logListProvider.notifier).delete(log.id!);
    }
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
    final day = DateFormat('M/d (E)', 'ko').format(log.drankAt);
    final tod = dt_utils.timeOfDayKorean(log.drankAt);
    final time = DateFormat('h:mm').format(log.drankAt);
    final dateStr = '$day $tod $time';
    final summary = log.entries
        .map((e) =>
            '${e.liquorNameRaw} ${e.quantityValue % 1 == 0 ? e.quantityValue.toInt() : e.quantityValue}${unitLabel(e.quantityUnit)}')
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

}

/// 월 헤더와 로그 타일을 섞어 단일 ListView 에 넣기 위한 구분자.
class _ListItem {
  final String? header;
  final DrinkLog? log;

  _ListItem.header(this.header) : log = null;
  _ListItem.log(this.log) : header = null;

  bool get isHeader => header != null;
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
