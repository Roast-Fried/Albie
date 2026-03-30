@Tags(['golden'])
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:albi/views/draft_review/draft_review_screen.dart';
import 'package:albi/viewmodels/draft_review_viewmodel.dart';
import 'package:albi/integrations/parser/parse_result.dart';
import 'golden_helper.dart';

void main() {
  setUpAll(setupGoldenTests);

  group('DraftReviewScreen Golden', () {
    testWidgets('AI parsed result', (tester) async {
      final state = DraftReviewState(
        source: 'ai_app_key',
        confidence: 0.85,
        parseWarnings: [],
        entries: [
          DraftEntry(
            liquorName: '벤로마크',
            liquorNameRaw: '벤로마크',
            liquorCategory: 'whisky',
            ageStatement: '15년',
            quantityValue: 2,
            quantityUnit: 'glass',
            isEstimated: false,
            alcoholPercent: 43.0,
          ),
        ],
        foodItems: ['육회', '치즈'],
        place: '바',
        drankAt: DateTime(2026, 3, 30, 22, 30),
        rawInputText: '벤로막 15 두 잔 육회랑 치즈 먹음',
      );

      await tester.pumpWidget(
        goldenWrapper(
          const DraftReviewScreen(),
          overrides: [
            draftReviewProvider
                .overrideWith((_) => DraftReviewViewModel(state)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/draft_review_ai.png'),
      );
    });

    testWidgets('low confidence with warnings', (tester) async {
      final state = DraftReviewState(
        source: 'local_parser',
        confidence: 0.55,
        parseWarnings: ['술 이름을 정확히 확인하지 못했습니다', '수량이 추정치입니다'],
        entries: [
          DraftEntry(
            liquorNameRaw: '위스키',
            liquorCategory: 'whisky',
            quantityValue: 1,
            quantityUnit: 'unknown',
            isEstimated: true,
          ),
        ],
        foodItems: [],
        drankAt: DateTime(2026, 3, 30, 23, 0),
        rawInputText: '위스키 조금 마셨는데 이름은 기억 안 남',
      );

      await tester.pumpWidget(
        goldenWrapper(
          const DraftReviewScreen(),
          overrides: [
            draftReviewProvider
                .overrideWith((_) => DraftReviewViewModel(state)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/draft_review_low_confidence.png'),
      );
    });

    testWidgets('manual input (empty form)', (tester) async {
      await tester.pumpWidget(
        goldenWrapper(
          const DraftReviewScreen(),
          overrides: [
            draftReviewProvider
                .overrideWith((_) => DraftReviewViewModel(DraftReviewState.manual())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/draft_review_manual.png'),
      );
    });
  });
}
