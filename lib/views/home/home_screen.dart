import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../viewmodels/app_settings_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/draft_review_viewmodel.dart';
import '../common/error_state_widget.dart';
import '../draft_review/draft_review_screen.dart';
import '../settings/ai_settings_screen.dart';
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
    final thisMonthCount = ref.watch(thisMonthLogCountProvider);
    final recentLiquors = ref.watch(recentFrequentLiquorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('알비', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'AI 처리 로그',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),
        ],
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
                  : RecentLogsWidget(
                      logs: logs,
                      onMore: () =>
                          ref.read(appTabIndexProvider.notifier).state = 1,
                    ),
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => ErrorStateWidget(
                message: '최근 기록을 불러오지 못했습니다',
                onRetry: () => ref.invalidate(recentLogsProvider),
              ),
            ),

            const SizedBox(height: 16),

            // 자연어 입력 영역
            InputSectionWidget(
              placeholders: _placeholders,
              inputText: homeState.inputText,
              imagePath: homeState.imagePath,
              imageName: homeState.imageName,
              isLoading: homeState.isLoading,
              onChanged: (text) =>
                  ref.read(homeViewModelProvider.notifier).updateInput(text),
              onPickImage: () =>
                  ref.read(homeViewModelProvider.notifier).pickImage(),
              onRemoveImage: () =>
                  ref.read(homeViewModelProvider.notifier).removeImage(),
              onGenerateDraft: () => _onGenerateDraft(context, ref),
              onCancelGenerate: () =>
                  ref.read(homeViewModelProvider.notifier).cancelGenerate(),
              onManualInput: () => _onManualInput(context, ref),
            ),

            if (homeState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                homeState.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            const SizedBox(height: 20),

            // 최근 마셔본 술 chips (최근 한 달)
            recentLiquors.when(
              data: (names) => names.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '최근 마셔본 술',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 36,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: names.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            // Round 6 X3 — Chip shrinkWrap 32dp tap target FAIL
                            // → 기본 padded 로 48dp 확보 (motor disability / 음주 후)
                            itemBuilder: (_, i) => Chip(label: Text(names[i])),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // 하단 "이번 달 N회" 지표
            thisMonthCount.when(
              data: (count) => count == 0
                  ? const _EmptyHint()
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_bar,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text('이번 달 $count회 기록'),
                          ],
                        ),
                      ),
                    ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => ErrorStateWidget(
                message: '통계를 불러오지 못했습니다',
                onRetry: () => ref.invalidate(thisMonthLogCountProvider),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _onGenerateDraft(BuildContext context, WidgetRef ref) async {
    final vm = ref.read(homeViewModelProvider.notifier);
    final homeState = ref.read(homeViewModelProvider);
    final inputText = homeState.inputText;
    final imagePath = homeState.imagePath;
    final result = await vm.generateDraft();
    if (result == null || !context.mounted) return;

    _navigateToReview(
      context,
      ref,
      DraftReviewState.fromParseResult(
        result.parseResult,
        rawInputText: inputText,
        rawImagePath: imagePath,
        parseJobId: result.parseJobId,
        wasAiAttempted: result.wasAiAttempted,
      ),
    );
    vm.clearInput();
  }

  void _onManualInput(BuildContext context, WidgetRef ref) {
    final state = ref.read(homeViewModelProvider);
    final settings =
        ref.read(appSettingsProvider).valueOrNull ?? const AppSettingsState();
    _navigateToReview(
      context,
      ref,
      DraftReviewState.manual(
        rawInputText: state.inputText,
        rawImagePath: state.imagePath,
        defaultQuantityUnit: settings.defaultQuantityUnit,
      ),
    );
    ref.read(homeViewModelProvider.notifier).clearInput();
  }

  void _navigateToReview(
    BuildContext context,
    WidgetRef ref,
    DraftReviewState initialState,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderScope(
          overrides: [
            draftReviewProvider.overrideWith(
              (_) => DraftReviewViewModel(initialState),
            ),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      // 살짝 강조된 surfaceContainer 로 첫 인상 polishing — 너무 밝지 않게.
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            // 원형 backdrop + icon — Material 3 empty state 패턴
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wine_bar_outlined,
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '아직 기록이 없어요',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '위에서 오늘 마신 술을 자연어로 입력해보세요',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
