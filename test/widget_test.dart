import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:albi/app.dart';

void main() {
  testWidgets('App renders bottom nav', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: AlbiApp()),
    );

    expect(find.text('홈'), findsWidgets);
    expect(find.text('기록'), findsWidgets);
    expect(find.text('더보기'), findsWidgets);
  });
}
