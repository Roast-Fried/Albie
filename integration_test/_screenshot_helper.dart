import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 스크린샷 저장 base 디렉터리.
/// - desktop(Windows/Linux/macOS): 프로젝트 cwd `test_screenshots` (직접 접근).
/// - 실기 device(Android/iOS): 앱 외부 파일 디렉터리 (adb pull 로 host 회수 가능).
Future<String> screenshotBaseDir() async {
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    final d =
        await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    return '${d.path}/test_screenshots';
  }
  return 'test_screenshots';
}

/// integration_test 공통 helper — mobile portrait viewport + screenshot 캡처 +
/// onboarding skip + dialog 안전 처리.
///
/// 모든 capture test 파일이 import 하여 재사용. parser_ui_test / layout_screenshot_test
/// 의 함수 통합.
///
/// 2026-05-26 작성 — Codex 페어 enumeration sprint Phase 1.

/// 모바일 세로 viewport 강제 (Pixel 5 비슷: logical 360x800 @ 3.0x = physical 1080x2400).
/// testWidgets 시작에서 호출 + addTearDown 으로 reset.
void enforceMobilePortrait(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// SharedPreferences 의 onboarding completed flag 강제 — 매 test 의 onboarding
/// 진입 일관성 보장. true = skip, false = 첫 진입.
Future<void> setOnboardingCompleted(bool completed) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_completed': completed,
  });
}

/// onboarding + theme mode 동시 강제 — 위스키 컨셉 light/dark 시각 검증용.
/// themeMode: 'light' / 'dark' / 'system'.
Future<void> setOnboardingAndTheme(bool completed, String themeMode) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_completed': completed,
    'theme_mode': themeMode,
  });
}

/// FlutterSecureStorage MethodChannel mock — gemini_api_key 등 비밀 key 를
/// integration_test 환경에서 in-memory 로 주입. transcript 노출 없이
/// `String.fromEnvironment('GEMINI_API_KEY')` 같은 dart-define 받아 처리.
final Map<String, String> _secureStorageMock = <String, String>{};

void setupSecureStorageMock(Map<String, String> initial) {
  _secureStorageMock
    ..clear()
    ..addAll(initial);
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    final args = (call.arguments as Map?) ?? const {};
    final key = args['key'] as String?;
    switch (call.method) {
      case 'read':
        return key != null ? _secureStorageMock[key] : null;
      case 'readAll':
        return Map<String, String>.from(_secureStorageMock);
      case 'write':
        final value = args['value'] as String?;
        if (key != null && value != null) {
          _secureStorageMock[key] = value;
        }
        return null;
      case 'delete':
        if (key != null) _secureStorageMock.remove(key);
        return null;
      case 'deleteAll':
        _secureStorageMock.clear();
        return null;
      case 'containsKey':
        return key != null && _secureStorageMock.containsKey(key);
    }
    return null;
  });
}

/// pumpAndSettle 하되 debounce/perpetual timer 로 settle 안 되면(timeout) 고정 pump
/// 로 폴백 — 텍스트 입력(master-matching debounce) 화면에서 pumpAndSettle 무한대기
/// hang 방지. settle 빠른 화면은 즉시 반환(기존 동작 유지).
Future<void> settleOrPump(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      timeout,
    );
  } catch (_) {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }
}

/// 화면 캡처 — topmost RenderRepaintBoundary (navigator push 된 route 우선) 캡처.
/// viewport 70% 면적 가드로 sub-boundary 잘못 잡힘 방지.
///
/// 2026-05-27: IndexedStack 의 비활성 child 도 paint 완료 (cache) 상태로 남아
/// reversed topmost 선택 시 첫 child (Home) 가 잡히는 회귀 — `activeScreen`
/// 인자로 active 화면 widget 의 하위 boundary 만 검색하도록 한정.
///
/// timing assertion (`debugNeedsPaint`) 회피를 위해 호출 전 pumpAndSettle + 추가
/// pump(500ms) 적용.
Future<void> takeShot(WidgetTester tester, String name,
    {Type? activeScreen}) async {
  // timing 안정화 — debugNeedsPaint assertion 회피 (전반 pump + frame stabilize).
  // settleOrPump: debounce timer 화면에서 pumpAndSettle 무한대기 방지.
  await settleOrPump(tester);
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));

  if (Platform.isAndroid || Platform.isIOS) return;
  try {
    RenderObject renderObject = tester.binding.rootElement!.renderObject!;

    // activeScreen 지정 시 해당 widget 하위에서만 boundary 검색 — IndexedStack
    // 의 비활성 child boundary 회피.
    if (activeScreen != null) {
      final screenFinder = find.byWidgetPredicate(
        (w) => w.runtimeType == activeScreen,
      );
      if (screenFinder.evaluate().isNotEmpty) {
        final screenElement = screenFinder.evaluate().first;
        final screenRender = screenElement.renderObject;
        if (screenRender != null) renderObject = screenRender;
      }
    }

    final boundaries = <RenderRepaintBoundary>[];
    void findBoundary(RenderObject obj) {
      if (obj is RenderRepaintBoundary) {
        boundaries.add(obj);
      }
      obj.visitChildren(findBoundary);
    }

    findBoundary(renderObject);
    final viewLogical =
        tester.view.physicalSize / tester.view.devicePixelRatio;
    // activeScreen 지정 시 — body 영역만 (AppBar/BottomNav 제외) 이라 50% 가드.
    final guardRatio = activeScreen != null ? 0.5 : 0.7;
    final minW = viewLogical.width * guardRatio;
    final minH = viewLogical.height * guardRatio;

    // IndexedStack 의 비활성 child boundary 는 paint 안 됨 → debugNeedsPaint true
    // 영구. paint 완료 + size 가드 통과한 boundary 우선 선택.
    RenderRepaintBoundary? boundary;
    double bestArea = 0;

    // 1차: paint 완료 + size 가드 통과 중 **면적 최대** 경계 선택.
    // 기존 'reversed(최심부) 우선' 은 Scaffold 의 body(ListView) 경계를 잡아 형제인
    // AppBar 가 캡처에서 제외됐다(full_light_*_more/settings 타이틀 누락 원인).
    // 면적 최대 = route/Scaffold 레벨 경계라 AppBar(+BottomNav)까지 포함하고,
    // IndexedStack 비활성 탭의 작은 body 경계 대신 활성 화면의 최상위 경계를
    // 잡으므로 'Home 경계 오선택' 회귀도 방지된다.
    //
    // `>=` (동률 시 마지막 우선) — pushed route(예: 설정/아카이브)와 뒤의
    // AppShell 이 둘 다 풀스크린(동일 면적)일 때, DFS 가 나중에 방문하는
    // 최상위 overlay(=실제로 보이는 push 화면)를 선택하기 위함. `>` 면 뒤의
    // 화면(더보기)이 잡혀 push 화면이 캡처 안 됨.
    for (final b in boundaries) {
      if (b.attached &&
          !b.debugNeedsPaint &&
          b.size.width >= minW &&
          b.size.height >= minH) {
        final area = b.size.width * b.size.height;
        if (area >= bestArea) {
          bestArea = area;
          boundary = b;
        }
      }
    }

    // 2차: size 가드만 통과한 것 중 면적 최대 (retry 로 paint 강제)
    if (boundary == null) {
      for (final b in boundaries) {
        if (!b.attached || b.size.width < minW || b.size.height < minH) continue;
        final area = b.size.width * b.size.height;
        if (area < bestArea) continue;
        // paint retry 최대 2초
        bool ready = false;
        for (int i = 0; i < 20; i++) {
          if (!b.debugNeedsPaint) {
            ready = true;
            break;
          }
          await tester.pump(const Duration(milliseconds: 100));
        }
        if (ready) {
          bestArea = area;
          boundary = b;
        }
      }
    }

    if (boundary != null) {
      if (boundary.debugNeedsPaint) {
        debugPrint('Screenshot skip ($name): debugNeedsPaint after 2s retry');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final base = await screenshotBaseDir();
        final dir = Directory(base);
        if (!dir.existsSync()) dir.createSync(recursive: true);
        File('$base/$name.png')
            .writeAsBytesSync(byteData.buffer.asUint8List());
        debugPrint('Screenshot: $name.png (${boundary.size}) -> $base');
      }
    } else {
      // 진단 — boundary 0개 또는 size 가드 통과 못함.
      final sizes =
          boundaries.map((b) => '${b.size.width.toInt()}x${b.size.height.toInt()}').take(8).join(', ');
      debugPrint('Screenshot skip ($name): no boundary passed guard. '
          'total=${boundaries.length}, sizes=[$sizes], guard=${minW.toInt()}x${minH.toInt()}');
    }
  } catch (e) {
    debugPrint('Screenshot failed ($name): $e');
  }
}

/// Onboarding skip — "건너뛰기" 버튼이 있으면 tap.
Future<void> skipOnboarding(WidgetTester tester) async {
  if (find.text('건너뛰기').evaluate().isNotEmpty) {
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}

/// 안전 back — BackButton tap + dialog "나가기" 처리. pumpAndSettle timeout
/// 5초 명시 (default 10분 무한 대기 방지).
Future<void> safeBack(WidgetTester tester) async {
  final back = find.byType(BackButton);
  if (back.evaluate().isEmpty) return;
  await tester.tap(back.first, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(seconds: 5));

  // PopScope dialog ("나가기") 처리
  if (find.text('나가기').evaluate().isNotEmpty) {
    await tester.tap(find.text('나가기'), warnIfMissed: false);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  }
}

/// 텍스트 tap — find.text 의 마지막 hit (BottomNav 의 라벨 우선).
Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) return;
  await tester.tap(f.last, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

/// TextField finder — labelText 매칭.
Finder textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
  );
}

/// TextField finder — hintText 매칭.
Finder textFieldByHint(String hint) {
  return find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint,
  );
}

/// 키보드 dismiss — desktop 환경에서 SystemChannels.textInput hide.
Future<void> hideKeyboard(WidgetTester tester) async {
  await SystemChannels.textInput.invokeMethod('TextInput.hide');
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

/// label 텍스트 + TextField 입력 헬퍼.
Future<void> enterByLabel(
    WidgetTester tester, String label, String text) async {
  final f = textFieldByLabel(label);
  if (f.evaluate().isEmpty) return;
  await tester.tap(f.first, warnIfMissed: false);
  await tester.pumpAndSettle(const Duration(seconds: 1));
  await tester.enterText(f.first, text);
  await tester.pumpAndSettle(const Duration(seconds: 1));
}
