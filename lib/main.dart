import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/app_config.dart';
import 'core/database/database_init.dart';
import 'integrations/notification/notification_service.dart';

/// 전역 crash handler — Flutter framework / async / platform 에러를 모두 캡처.
///
/// debug 모드: console + Flutter 빨간 화면 그대로 (개발자 진단 우선).
/// release 모드: 사용자에게 친화 fallback UI + console 로깅 (향후 crash 보고
/// 서비스 연동 지점). 앱 전체 종료 대신 위젯 단위 회복.
void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // .env 로드 — credential(Supabase/Gemini) 주입. 파일이 없거나 비어 있어도
      // 진행하며, 이 경우 관련 기능은 dormant 로 기존 로컬 동작을 유지한다.
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // .env asset 부재/파싱 실패 — dormant 로 계속.
      }

      // 한국어 날짜 포맷(캘린더/날짜 표기) locale 데이터 초기화.
      await initializeDateFormatting('ko_KR', null);

      // Supabase — credential 이 채워졌을 때만 초기화. 미설정이면 dormant 로
      // 클라우드 기능만 비활성, 나머지 로컬 동작은 그대로 유지된다.
      if (AppConfig.hasSupabase) {
        try {
          await Supabase.initialize(
            url: AppConfig.supabaseUrl,
            anonKey: AppConfig.supabaseAnonKey,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('Supabase init 실패: $e');
        }
      }

      // 1) Flutter framework 에러 (build/layout/paint)
      //    PII 보호: release 모드는 console 출력 0 — stack trace 가 사용자 입력 /
      //    API key 일부 등을 포함할 수 있다. debug 모드만 console 출력.
      //    향후 Sentry/Crashlytics 통합 시 release 분기에서 안전 채널로 전송.
      FlutterError.onError = (FlutterErrorDetails details) {
        if (kDebugMode) {
          FlutterError.presentError(details);
          debugPrint('🔥 Flutter error: ${details.exceptionAsString()}');
          if (details.stack != null) debugPrint(details.stack.toString());
        }
      };

      // 2) Platform (engine) 단의 비동기 에러
      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) {
          debugPrint('🔥 Platform error: $error');
          debugPrint(stack.toString());
        }
        return true; // 처리 완료 — 앱 종료 안 함
      };

      // 3) Release 모드 위젯 build 실패 시 빨간 화면 대신 사용자 친화 fallback.
      //    debug 모드는 기존 ErrorWidget (빨간 화면) 유지 — 진단 우선.
      if (kReleaseMode) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return _CrashFallback(message: details.exceptionAsString());
        };
      }

      initDatabaseFactory();
      // Phase C2 알림 service — timezone DB + Android channel 초기화. 권한 요청
      // 은 onboarding 또는 Settings 의 명시 사용자 액션 시점에 별도.
      unawaited(NotificationService.instance.init());
      runApp(const ProviderScope(child: AlbiApp()));
    },
    (Object error, StackTrace stack) {
      // 4) Zone 캡처 — runZoned 안의 모든 미처리 async 에러
      //    PII 보호: release 모드에서는 출력 차단.
      if (kDebugMode) {
        debugPrint('🔥 Zone error: $error');
        debugPrint(stack.toString());
      }
    },
  );
}

/// 사용자 친화 fallback UI — release 모드 위젯 build 실패 시 노출.
///
/// 빨간 화면 대신 한국어 메시지 + 재시도 안내. 앱 전체가 아닌 해당 위젯만
/// 교체 (다른 화면은 정상 동작 유지). 향후 crash 보고 버튼 추가 가능.
class _CrashFallback extends StatelessWidget {
  const _CrashFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                '일시적인 오류가 발생했습니다',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '다른 화면으로 이동하거나 앱을 다시 실행해 주세요.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
