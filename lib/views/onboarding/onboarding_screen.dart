import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: const [
                  _Page1Welcome(),
                  _Page2Parser(),
                  _Page3Benefits(),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  _pageCount,
                  (i) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPage
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                      )),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _currentPage == _pageCount - 1
                      ? _complete
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut),
                  child: Text(_currentPage == _pageCount - 1
                      ? '🥃 시작하기'
                      : '다음'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_currentPage < _pageCount - 1)
              TextButton(
                onPressed: _complete,
                child: const Text('건너뛰기'),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }
}

/// 페이지 1 — 환영 + 입력→결과 변환 예시.
class _Page1Welcome extends StatelessWidget {
  const _Page1Welcome();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wine_bar,
              size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text('알비에 오신 걸 환영합니다',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('한 줄 입력으로 음주 기록을 자동으로 정리해드려요',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          // 변환 예시
          _ExampleBox(
            emoji: '🗣',
            text: '"글렌피딕 12 두 잔 마셨어"',
          ),
          const SizedBox(height: 6),
          Icon(Icons.arrow_downward_rounded,
              color: Theme.of(context).colorScheme.outline, size: 20),
          const SizedBox(height: 6),
          _ExampleBox(
            emoji: '🥃',
            text: '글렌피딕 12년 · 2잔 · 위스키',
            highlight: true,
          ),
        ],
      ),
    );
  }
}

/// 페이지 2 — 로컬 파서 vs AI 파서 카드 병렬.
class _Page2Parser extends StatelessWidget {
  const _Page2Parser();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.offline_bolt_outlined,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text('AI 없이도 동작해요',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('기본으로 로컬 파서가 도와드립니다.\nAI를 연결하면 더 정확해져요.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(
                child: _ParserCard(
                  emoji: '📱',
                  title: '로컬 파서',
                  sub: '기본 · 항상 사용 가능',
                  detail: '인터넷 불필요',
                  isPrimary: true,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _ParserCard(
                  emoji: '🤖',
                  title: 'AI 파서',
                  sub: '선택 · 더 정확',
                  detail: 'Gemini API 키 필요',
                  isPrimary: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 페이지 3 — 시작하기 + 3 benefit 그리드.
class _Page3Benefits extends StatelessWidget {
  const _Page3Benefits();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          Text('이제 시작해요',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('기록이 쌓일수록 더 유용해진답니다',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          Row(
            children: const [
              Expanded(
                  child: _BenefitTile(
                      emoji: '📊', label: '통계', sub: '패턴 파악')),
              SizedBox(width: 10),
              Expanded(
                  child: _BenefitTile(
                      emoji: '🗃', label: '아카이브', sub: '마셔본 술')),
              SizedBox(width: 10),
              Expanded(
                  child: _BenefitTile(
                      emoji: '✍️', label: '노트', sub: '테이스팅')),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 재사용 블록 ──

class _ExampleBox extends StatelessWidget {
  final String emoji;
  final String text;
  final bool highlight;

  const _ExampleBox({
    required this.emoji,
    required this.text,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = highlight
        ? Theme.of(context).colorScheme.onPrimaryContainer
        : Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: fg, fontSize: 14),
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _ParserCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String sub;
  final String detail;
  final bool isPrimary;

  const _ParserCard({
    required this.emoji,
    required this.title,
    required this.sub,
    required this.detail,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(sub,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 8),
          Text(detail,
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String sub;

  const _BenefitTile({
    required this.emoji,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }
}
