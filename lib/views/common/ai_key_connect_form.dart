import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';
import '../../viewmodels/ai_settings_viewmodel.dart';

/// Gemini API 키 발급(외부 브라우저) → 붙여넣기 → 검증·저장 까지 한 곳에서
/// 처리하는 재사용 폼. 홈의 AiKeyGuideSheet 와 첫 실행 온보딩에서 공용으로 쓴다.
///
/// 브라우저에서 키를 복사하고 앱으로 돌아오면(앱 resume) 클립보드를 확인해
/// Gemini 키 형태면 자동으로 채워 거의 원탭으로 연결되게 한다.
class AiKeyConnectForm extends ConsumerStatefulWidget {
  /// 키 검증·저장 성공 시 호출.
  final VoidCallback? onRegistered;

  const AiKeyConnectForm({super.key, this.onRegistered});

  @override
  ConsumerState<AiKeyConnectForm> createState() => _AiKeyConnectFormState();
}

class _AiKeyConnectFormState extends ConsumerState<AiKeyConnectForm>
    with WidgetsBindingObserver {
  static const _apiKeyUrl = 'https://aistudio.google.com/apikey';

  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  bool _launchedBrowser = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 브라우저에서 키 복사 후 돌아왔을 때만 클립보드 자동 채움.
    if (state == AppLifecycleState.resumed &&
        _launchedBrowser &&
        _keyCtrl.text.trim().isEmpty) {
      _launchedBrowser = false;
      _tryFillFromClipboard();
    }
  }

  Future<void> _tryFillFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (_looksLikeKey(text) && mounted) {
      setState(() => _keyCtrl.text = text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복사한 키를 붙여넣었어요')),
      );
    }
  }

  // Gemini API 키 휴리스틱 — "AIza" 접두 + 충분한 길이 + 공백 없음.
  bool _looksLikeKey(String s) =>
      s.startsWith('AIza') && s.length >= 35 && !s.contains(RegExp(r'\s'));

  Future<void> _openBrowser() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(
        Uri.parse(_apiKeyUrl),
        mode: LaunchMode.externalApplication,
      );
      if (ok) {
        _launchedBrowser = true;
      } else if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('브라우저를 열 수 없습니다')),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('브라우저를 열 수 없습니다')),
        );
      }
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty && mounted) {
      setState(() {
        _keyCtrl.text = text;
        _error = null;
      });
    }
  }

  Future<void> _save() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) {
      setState(() => _error = '키를 입력해주세요');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    // 온보딩(AppShell 진입 전)에서도 호출될 수 있어 repo 의 DB 준비를 선행 보장.
    // (aiConfigRepoProvider 가 databaseProvider.requireValue 를 요구)
    await ref.read(databaseProvider.future);
    final error = await ref.read(aiConfigProvider.notifier).saveApiKey(key);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    setState(() => _saving = false);
    widget.onRegistered?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('연결 단계', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              _step(theme, '1', "'키 발급 페이지 열기' 를 누르면 브라우저가 열려요"),
              _step(theme, '2', 'Google 로그인 후 "Create API key" 클릭'),
              _step(theme, '3', '발급된 키를 복사하고 앱으로 돌아오기'),
              _step(theme, '4', '키가 자동으로 채워지면 "연결하기" 탭'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _saving ? null : _openBrowser,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('키 발급 페이지 열기'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _keyCtrl,
          obscureText: _obscure,
          enabled: !_saving,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: 'Gemini API Key',
            errorText: _error,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.paste, size: 20),
                  tooltip: '붙여넣기',
                  onPressed: _saving ? null : _paste,
                ),
                IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                  ),
                  tooltip: _obscure ? '키 표시' : '키 숨기기',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link, size: 18),
          label: Text(_saving ? '검증 중...' : '연결하기'),
        ),
        const SizedBox(height: 8),
        Text(
          '⚠️ 무료 Gemini API 사용 시 입력 내용이 Google 제품 개선에 사용될 수 있어요.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _step(ThemeData theme, String n, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$n. ',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
