import 'package:flutter/material.dart';
import '../../core/theme/app_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/parse_job.dart';
import '../../viewmodels/ai_settings_viewmodel.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _keyCtrl = TextEditingController();
  bool _keyVisible = false;

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(aiConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 연결 설정')),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (state) => ListView(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
          children: [
            // AI 사용 토글
            SwitchListTile(
              title: const Text('AI 사용'),
              value: state.config.isEnabled,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).toggleEnabled(v),
            ),
            const Divider(),

            // API 키 연결 가이드 (키 미등록 시)
            if (!state.hasUserKey) ...[
              const _SectionHeader('Gemini API 키 연결'),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 자동 분석을 사용하려면 본인 Gemini API 키가 필요합니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('연결 단계',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      const Text('1. https://aistudio.google.com/apikey 접속'),
                      const Text('2. "Create API key" 버튼 클릭'),
                      const Text('3. 발급된 키 복사 후 아래 입력란에 붙여넣기'),
                      const Text('4. ✓ 버튼으로 저장 + 자동 검증'),
                      const SizedBox(height: 8),
                      Text(
                        "* 키를 등록하기 전에는 'AI로 생성'이 연결 안내를 표시하며, '직접 입력'으로 기록할 수 있어요.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _keyCtrl,
                obscureText: !_keyVisible,
                decoration: InputDecoration(
                  hintText: 'Gemini API Key',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(_keyVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        tooltip: _keyVisible ? '키 숨기기' : '키 표시',
                        onPressed: () =>
                            setState(() => _keyVisible = !_keyVisible),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        tooltip: '키 저장 및 검증',
                        onPressed: () => _saveKey(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '⚠️ 무료 Gemini API 사용 시 입력 내용이 Google 제품 개선에 사용될 수 있습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const Divider(),
            ] else ...[
              const _SectionHeader('API Key'),
              ListTile(
                title: const Text('키 등록됨'),
                subtitle: state.config.lastValidatedAt != null
                    ? Text(
                        '마지막 검증: ${DateFormat('M/d HH:mm').format(state.config.lastValidatedAt!)}')
                    : null,
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(aiConfigProvider.notifier).deleteApiKey(),
                  child: const Text('삭제'),
                ),
              ),
              const Divider(),
            ],

            // 모델 선택
            const _SectionHeader('모델'),
            RadioListTile<String>(
              title: const Text('Flash Lite (빠름)'),
              subtitle: const Text('gemini-2.5-flash-lite'),
              value: 'gemini-2.5-flash-lite',
              groupValue: state.config.selectedModel,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).selectModel(v!),
            ),
            RadioListTile<String>(
              title: const Text('Flash (더 정확)'),
              subtitle: const Text('gemini-2.5-flash'),
              value: 'gemini-2.5-flash',
              groupValue: state.config.selectedModel,
              onChanged: (v) =>
                  ref.read(aiConfigProvider.notifier).selectModel(v!),
            ),
            const Divider(),

            // 오늘 사용량
            const _SectionHeader('오늘 사용량'),
            ListTile(
              title: const Text('텍스트'),
              trailing: Text('${state.quota.userKeyTextCount}회'),
            ),
            ListTile(
              title: const Text('이미지'),
              trailing: Text('${state.quota.userKeyImageCount}회'),
            ),

            // 마지막 에러
            if (state.config.lastErrorMessage != null) ...[
              const Divider(),
              ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('마지막 오류'),
                subtitle: Text(state.config.lastErrorMessage!,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],

            const Divider(),
            const _SectionHeader('최근 처리 로그'),
            const _RecentJobsList(),
          ],
        ),
      ),
    );
  }

  Future<void> _saveKey() async {
    final error =
        await ref.read(aiConfigProvider.notifier).saveApiKey(_keyCtrl.text);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } else {
      _keyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API Key가 등록되었습니다')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: AppPalette.accentText(Theme.of(context).brightness))),
    );
  }
}

class _RecentJobsList extends ConsumerWidget {
  const _RecentJobsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(recentParseJobsProvider);
    return jobsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const Padding(
        padding: EdgeInsets.all(12),
        child: Text('로그를 불러올 수 없습니다', style: TextStyle(fontSize: 12)),
      ),
      data: (jobs) {
        if (jobs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('기록된 파싱 작업이 없습니다',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          );
        }
        return Column(
          children: jobs.map((j) => _JobTile(job: j)).toList(),
        );
      },
    );
  }
}

class _JobTile extends StatelessWidget {
  final ParseJob job;
  const _JobTile({required this.job});

  String _parserLabel(String raw) {
    if (raw.contains('flash-lite')) return 'Flash Lite';
    if (raw.contains('flash')) return 'Flash';
    if (raw == 'local_parser') return '로컬 파서';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(job.createdAt);
    final dur = job.durationMs != null ? '${job.durationMs}ms' : '-';
    final isSuccess = job.status == 'success';
    // a11y: 색상만으로 성공/실패 구분 → 스크린리더용 텍스트 라벨 추가.
    final statusIcon = Semantics(
      label: isSuccess ? '성공' : '실패',
      child: isSuccess
          ? Icon(Icons.check_circle, size: 16, color: Colors.green.shade600)
          : Icon(Icons.cancel, size: 16, color: Colors.red.shade600),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(time,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppPalette.accentText(Theme.of(context).brightness),
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Expanded(
            child: Text(
              '${job.sourceType == 'text_only' ? '텍스트' : '이미지'} · ${_parserLabel(job.parserUsed)}',
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(dur,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: 6),
          statusIcon,
        ],
      ),
    );
  }
}
