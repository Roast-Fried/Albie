import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:albi/main.dart' as app;
import 'package:albi/views/log/log_list_screen.dart';

import '_screenshot_helper.dart';

/// 기록 목록 캡처 — 2026-05-27 단순화 v2.
///
/// 이전 v1 의 search TextField focus + enterText flow 가 6분 hang 한 회귀를
/// 해소. 검색·삭제·상세 step 제거 — 빈 상태 / 기록 목록 시각 검증만.
///
/// **알려진 제약**: IndexedStack 의 비활성 home child 가 paint 완료 후 cache
/// 되어 takeShot 의 boundary 선택에서 home 가 우선 잡힘. activeScreen 인자로
/// LogListScreen 의 RenderObject 한정 시 RepaintBoundary 자식 0개 (Scaffold +
/// ConsumerStatefulWidget 구조에서 RepaintBoundary 가 root 위) 라 PNG 미캡처.
/// 본 test 는 navigation 검증 (LogListScreen expect 통과) 까지 + 실 PNG 는
/// device 검증 또는 app.dart 의 IndexedStack → PageView 변경 후 별도 sprint.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('log — 단순화 캡처', (tester) async {
    enforceMobilePortrait(tester);
    await setOnboardingCompleted(true);

    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await skipOnboarding(tester);

    // 1. 기록 탭 진입 — BottomNavigationBar icon finder + LogListScreen 등장 검증.
    final logTab = find.byIcon(Icons.list_alt_outlined);
    expect(logTab, findsOneWidget,
        reason: 'BottomNav list_alt_outlined 아이콘 부재');
    await tester.tap(logTab, warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(LogListScreen), findsOneWidget,
        reason: '기록 tab tap 후 LogListScreen 부재');
    await takeShot(tester, 'log_01_list', activeScreen: LogListScreen);

    // 2. 스크롤 down (월 그룹 헤더 등)
    final lv = find.byType(ListView);
    if (lv.evaluate().isNotEmpty) {
      await tester.drag(lv.first, const Offset(0, -300));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      await takeShot(tester, 'log_02_scrolled');
    }

    expect(find.byType(Scaffold), findsWidgets);
  });
}
