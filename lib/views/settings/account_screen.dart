import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/exceptions.dart';
import '../../core/providers.dart';
import '../../integrations/supabase/supabase_providers.dart';
import '../../integrations/supabase/supabase_sync_service.dart';
import '../../viewmodels/account_viewmodel.dart';
import '../../viewmodels/archive_viewmodel.dart';
import '../../viewmodels/calendar_viewmodel.dart';
import '../../viewmodels/log_list_viewmodel.dart';
import '../../viewmodels/settings_viewmodel.dart';
import '../../viewmodels/stats_viewmodel.dart';
import '../common/delete_confirm_dialog.dart';
import '../common/error_state_widget.dart';

/// 클라우드 백업·동기화 화면 — Supabase opt-in.
///
/// `.env` 미설정 시 안내 카드만 표시(기존 로컬 동작 유지). 설정 시 이메일 로그인
/// 후 백업/복원. offline-first: 로컬이 SoT, 복원은 명시 확인 후 로컬 교체.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(accountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('클라우드 백업·동기화')),
      body: accountAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorStateWidget(
          message: '계정 정보를 불러올 수 없습니다',
          onRetry: () => ref.invalidate(accountProvider),
        ),
        data: (info) {
          if (!info.configured) return const _UnconfiguredCard();
          if (!info.loggedIn) return _buildLoginForm();
          return _buildLoggedIn(info);
        },
      ),
    );
  }

  // ── 로그인/가입 폼 ──
  Widget _buildLoginForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '이메일로 로그인하면 기록을 클라우드에 백업하고 다른 기기에서 복원할 수 있어요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailCtrl,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: '이메일',
            prefixIcon: Icon(Icons.email_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pwCtrl,
          enabled: !_busy,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '비밀번호 (6자 이상)',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('로그인'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _busy ? null : _signUp,
          child: const Text('새 계정 만들기'),
        ),
      ],
    );
  }

  // ── 로그인 후: 백업/복원 ──
  Widget _buildLoggedIn(AccountInfo info) {
    final sync = ref.watch(supabaseSyncServiceProvider);
    final lastBackup = info.lastBackupAt != null
        ? DateFormat('y.M.d HH:mm', 'ko').format(info.lastBackupAt!)
        : '없음';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(info.email ?? ''),
          subtitle: const Text('로그인됨'),
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('마지막 백업'),
          trailing: Text(lastBackup),
          contentPadding: EdgeInsets.zero,
        ),
        if (sync != null)
          StreamBuilder<SyncStatus>(
            stream: sync.statusStream,
            builder: (context, snap) =>
                _statusBanner(snap.data ?? SyncStatus.idle),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _backup,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('지금 백업하기'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restore,
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('클라우드에서 복원하기'),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _busy ? null : _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('로그아웃'),
        ),
      ],
    );
  }

  Widget _statusBanner(SyncStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      SyncStatus.syncing => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('동기화 중...', style: TextStyle(color: scheme.primary)),
            ],
          ),
        ),
      SyncStatus.error => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('동기화 오류', style: TextStyle(color: scheme.error)),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  // ── 액션 ──
  Future<void> _signIn() => _run(
        () => ref
            .read(accountProvider.notifier)
            .signIn(_emailCtrl.text, _pwCtrl.text),
      );

  Future<void> _signUp() => _run(
        () => ref
            .read(accountProvider.notifier)
            .signUp(_emailCtrl.text, _pwCtrl.text),
        successMsg: '가입 완료! 이메일 확인이 필요할 수 있어요.',
      );

  Future<void> _signOut() =>
      _run(() => ref.read(accountProvider.notifier).signOut());

  Future<void> _backup() {
    final sync = ref.read(supabaseSyncServiceProvider);
    if (sync == null) return Future.value();
    return _run(() async {
      final n = await sync.backup();
      await ref.read(accountProvider.notifier).markBackedUp();
      if (mounted) _snack('$n건의 기록을 백업했어요');
    });
  }

  Future<void> _restore() async {
    final sync = ref.read(supabaseSyncServiceProvider);
    if (sync == null) return;
    await _run(() async {
      // 1) 네트워크에서 먼저 가져온다 — 실패해도 로컬은 그대로(offline-first).
      final logs = await sync.fetchBackup();
      if (logs == null) {
        if (mounted) _snack('클라우드에 백업이 없어요');
        return;
      }
      // 2) fetch 성공 후에만 확인 → 로컬 교체.
      if (!mounted) return;
      final ok = await showDeleteConfirmDialog(
        context,
        title: '클라우드에서 복원',
        content: '클라우드 백업 ${logs.length}건으로 현재 기기 기록을 교체합니다.\n'
            '현재 기록은 사라집니다. 계속하시겠습니까?',
      );
      if (ok != true) return;
      await resetAllRecords(ref); // fetch 성공 후이므로 안전
      await sync.applyRestore(logs);
      _invalidateData();
      if (mounted) _snack('${logs.length}건의 기록을 복원했어요');
    });
  }

  /// 복원 후 화면 데이터 갱신 — resetAllRecords 가 일부 invalidate 하지만
  /// 복원 insert 이후 다시 갱신해야 한다.
  void _invalidateData() {
    ref.invalidate(recentLogsProvider);
    ref.invalidate(logCountProvider);
    ref.invalidate(thisMonthLogCountProvider);
    ref.invalidate(logListProvider);
    ref.invalidate(archiveListProvider);
    ref.invalidate(settingsDataProvider);
    ref.invalidate(statsProvider);
    ref.invalidate(calendarLogsByDayProvider);
  }

  Future<void> _run(Future<void> Function() op, {String? successMsg}) async {
    setState(() => _busy = true);
    try {
      await op();
      if (mounted && successMsg != null) _snack(successMsg);
    } on AppError catch (e) {
      if (mounted) _snack(e.userMessage);
    } catch (_) {
      if (mounted) _snack('처리 중 오류가 발생했어요');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// `.env` 미설정 안내 — 클라우드 기능 비활성 상태.
class _UnconfiguredCard extends StatelessWidget {
  const _UnconfiguredCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_outlined, size: 40, color: scheme.outline),
                const SizedBox(height: 12),
                Text(
                  '클라우드 백업이 설정되지 않았어요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '앱은 지금도 모든 기능이 정상 동작합니다. 클라우드 백업·복원을 쓰려면 '
                  'Supabase 프로젝트를 만들고 .env 에 URL·키를 채운 뒤 다시 빌드하세요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  '설정 방법: docs/supabase-setup.md\n테이블 생성 SQL: docs/supabase-schema.sql',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
