import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/draft_review_viewmodel.dart';
import '../draft_review/draft_review_screen.dart';
import 'widgets/recent_logs_widget.dart';
import 'widgets/input_section_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _placeholders = [
    '나 오늘 벤로막 15 두 잔 마셨어',
    '하이볼 한 잔이랑 육회 먹음',
    '글렌피딕 12 바에서 한 잔',
    '맥주 3캔 마심',
    '위스키 조금 마셨는데 이름은 기억 안 남',
    '소주 반 병이랑 삼겹살',
    '잭다니엘 샷 3개',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeViewModelProvider);
    final recentLogs = ref.watch(recentLogsProvider);
    final logCount = ref.watch(logCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알비', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // 최근 기록 위젯
            recentLogs.when(
              data: (logs) => logs.isEmpty
                  ? const SizedBox.shrink()
                  : RecentLogsWidget(logs: logs),
              loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),

            // 자연어 입력 영역
            InputSectionWidget(
              placeholders: _placeholders,
              inputText: homeState.inputText,
              isLoading: homeState.isLoading,
              onChanged: (text) =>
                  ref.read(homeViewModelProvider.notifier).updateInput(text),
              onGenerateDraft: () => _onGenerateDraft(context, ref),
              onManualInput: () => _onManualInput(context, ref),
            ),

            if (homeState.error != null) ...[
              const SizedBox(height: 8),
              Text(homeState.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],

            const SizedBox(height: 24),

            // 하단 통계
            logCount.when(
              data: (count) => count == 0
                  ? const _EmptyHint()
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          Icon(Icons.local_bar,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Text('총 $count건 기록'),
                        ]),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _onGenerateDraft(BuildContext context, WidgetRef ref) async {
    final vm = ref.read(homeViewModelProvider.notifier);
    final inputText = ref.read(homeViewModelProvider).inputText;
    final result = await vm.generateDraft();
    if (result == null || !context.mounted) return;

    _navigateToReview(
      context,
      ref,
      DraftReviewState.fromParseResult(
        result.parseResult,
        rawInputText: inputText,
        parseJobId: result.parseJobId,
      ),
    );
    vm.clearInput();
  }

  void _onManualInput(BuildContext context, WidgetRef ref) {
    final inputText = ref.read(homeViewModelProvider).inputText;
    _navigateToReview(
      context,
      ref,
      DraftReviewState.manual(rawInputText: inputText),
    );
    ref.read(homeViewModelProvider.notifier).clearInput();
  }

  void _navigateToReview(
      BuildContext context, WidgetRef ref, DraftReviewState initialState) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          overrides: [
            draftReviewProvider
                .overrideWith((_) => DraftReviewViewModel(initialState)),
          ],
          child: const DraftReviewScreen(),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.wine_bar_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text('아직 기록이 없어요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('위에서 오늘 뭐 마셨는지 입력해보세요',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
