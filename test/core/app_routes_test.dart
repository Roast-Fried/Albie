import 'package:albi/core/app_routes.dart';
import 'package:albi/views/common/route_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateRoute — 유효 경로는 Route 반환 (페이지 빌드 전, 인자 검증)', () {
    test('인자 없는 경로들은 Route 를 반환', () {
      for (final name in [
        Routes.archive,
        Routes.stats,
        Routes.calendar,
        Routes.settings,
        Routes.aiSettings,
        Routes.notifications,
      ]) {
        expect(
          generateRoute(RouteSettings(name: name)),
          isA<Route<dynamic>>(),
          reason: name,
        );
      }
    });

    test('logDetail/archiveDetail 는 int 인자로 Route 반환', () {
      expect(
        generateRoute(const RouteSettings(name: Routes.logDetail, arguments: 1)),
        isA<Route<dynamic>>(),
      );
      expect(
        generateRoute(
            const RouteSettings(name: Routes.archiveDetail, arguments: 9)),
        isA<Route<dynamic>>(),
      );
    });
  });

  group('generateRoute — 잘못된 경로/인자는 RouteErrorScreen', () {
    testWidgets('알 수 없는 경로 → RouteErrorScreen', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        onGenerateRoute: generateRoute,
        home: const Scaffold(),
      ));
      navKey.currentState!.pushNamed('/이런-경로-없음');
      await tester.pumpAndSettle();
      expect(find.byType(RouteErrorScreen), findsOneWidget);
    });

    testWidgets('logDetail 에 int 아닌 인자 → RouteErrorScreen', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        onGenerateRoute: generateRoute,
        home: const Scaffold(),
      ));
      // arguments 미전달(null) → int 아님 → 에러 라우트
      navKey.currentState!.pushNamed(Routes.logDetail);
      await tester.pumpAndSettle();
      expect(find.byType(RouteErrorScreen), findsOneWidget);
    });

    testWidgets('draftReview 에 잘못된 인자 → RouteErrorScreen', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        onGenerateRoute: generateRoute,
        home: const Scaffold(),
      ));
      navKey.currentState!.pushNamed(Routes.draftReview, arguments: 'nope');
      await tester.pumpAndSettle();
      expect(find.byType(RouteErrorScreen), findsOneWidget);
    });
  });
}
