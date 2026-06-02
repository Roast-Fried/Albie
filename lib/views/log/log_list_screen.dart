import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/app_routes.dart';
import '../../core/providers.dart';
import '../../core/utils/date_utils.dart' as dt_utils;
import '../../core/utils/label_utils.dart';
import '../../viewmodels/log_list_viewmodel.dart';
import '../../domain/entities/drink_log.dart';
import '../common/animations.dart';
import '../common/delete_confirm_dialog.dart';
import '../common/error_state_widget.dart';

class LogListScreen extends ConsumerStatefulWidget {
  const LogListScreen({super.key});

  @override
  ConsumerState<LogListScreen> createState() => _LogListScreenState();
}

class _LogListScreenState extends ConsumerState<LogListScreen> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // debounce 300ms — 빠른 타이핑 시 DB query 폭주 방지
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      ref.read(logListProvider.notifier).search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(logListProvider);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

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
                onChanged: _onSearchChanged,
              )
            : const Text('기록'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchDebounce?.cancel();
                  _searchCtrl.clear();
                  ref.read(logListProvider.notifier).refresh();
                }
              });
            },
          ),
        ],
      ),
      // 2026-05-27 Codex Sprint 4 audit N-2 (LOW): integration_test 의 takeShot 이
      // IndexedStack 환경에서 active screen subtree 안에서 RepaintBoundary 를 찾지
      // 못해 PNG 미캡처. body 를 RepaintBoundary 로 wrap 하여 캡처 가능 + scroll
      // 시 repaint 영역 격리 효과.
      body: RepaintBoundary(
        // 로딩/빈/데이터 상태 전환을 부드럽게 cross-fade (암시적 애니메이션).
        // 키를 상태 종류로만 구분해 data→data(refresh) 시 재애니메이션을 막는다.
        child: AnimatedSwitcher(
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          ),
          child: logsAsync.when(
            loading: () => const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
                key: const ValueKey('error'),
                message: '기록을 불러올 수 없습니다',
                onRetry: () => ref.read(logListProvider.notifier).refresh()),
            data: (logs) => logs.isEmpty
                ? const _EmptyState(key: ValueKey('empty'))
                : RefreshIndicator(
                    key: const ValueKey('data'),
                    onRefresh: () =>
                        ref.read(logListProvider.notifier).refresh(),
                    child: _buildGroupedList(context, ref, logs),
                  ),
          ),
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
        return AppearAnimation(
          child: _LogTile(
            log: log,
            onTap: () => _openDetail(context, log),
            onDelete: () => _confirmDelete(context, ref, log),
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, DrinkLog log) {
    Navigator.of(context)
        .pushNamed(Routes.logDetail, arguments: log.id!)
        .then((_) => ref.read(logListProvider.notifier).refresh());
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, DrinkLog log) async {
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
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              // long-press 는 기존 호환성 유지 — 새 사용자는 trailing 휴지통 button 사용
              onLongPress: onDelete,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
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
          ),
          // 명시적 삭제 button — TalkBack / motor disability 대응 (long-press alternative)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '기록 삭제',
              onPressed: onDelete,
              iconSize: 20,
            ),
          ),
        ],
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

class _EmptyState extends ConsumerWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notes_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          const Text('아직 기록이 없어요'),
          const SizedBox(height: 4),
          Text('오늘 뭐 마셨어요? 한 줄로 알려주세요!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('첫 기록 남기기'),
            onPressed: () =>
                ref.read(appTabIndexProvider.notifier).state = 0,
          ),
        ],
      ),
    );
  }
}
