import 'package:albi/views/common/brand_illustration.dart';
import 'package:albi/views/common/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BrandIllustration — 전 variant 렌더 (paint 예외 없음)',
      (tester) async {
    for (final v in AlbiIllustration.values) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: BrandIllustration(variant: v)))),
      );
      expect(find.byType(BrandIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('EmptyStateWidget — 제목/메시지/CTA 표시 + 탭', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            illustration: AlbiIllustration.emptyGlass,
            title: '아직 기록이 없어요',
            message: '첫 기록을 남겨보세요',
            actionLabel: '첫 기록',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('아직 기록이 없어요'), findsOneWidget);
    expect(find.text('첫 기록을 남겨보세요'), findsOneWidget);
    await tester.tap(find.text('첫 기록'));
    expect(tapped, isTrue);
  });
}
