import 'package:flutter_test/flutter_test.dart';
import 'package:albi/viewmodels/draft_review_viewmodel.dart';
import 'package:albi/integrations/parser/parse_result.dart';

void main() {
  group('DraftReviewViewModel', () {
    test('addEntry increases count', () {
      final vm = DraftReviewViewModel(DraftReviewState.manual());
      expect(vm.state.entries.length, 1);
      vm.addEntry();
      expect(vm.state.entries.length, 2);
    });

    test('removeEntry keeps minimum 1', () {
      final vm = DraftReviewViewModel(DraftReviewState.manual());
      vm.removeEntry(0);
      expect(vm.state.entries.length, 1); // 삭제 안 됨
    });

    test('updatePlace/updateMemo', () {
      final vm = DraftReviewViewModel(DraftReviewState.manual());
      vm.updatePlace('바');
      expect(vm.state.place, '바');
      vm.updateMemo('좋았다');
      expect(vm.state.overallMemo, '좋았다');
    });

    test('addFood ignores duplicates', () {
      final vm = DraftReviewViewModel(DraftReviewState.manual());
      vm.addFood('육회');
      vm.addFood('육회');
      expect(vm.state.foodItems.length, 1);
    });

    test('fromParseResult populates state', () {
      final result = ParseResult(
        source: 'local_parser',
        confidence: 0.75,
        entries: [DraftEntry(liquorNameRaw: '벤로마크', liquorCategory: 'whisky')],
        foodItems: ['육회'],
        place: '바',
      );
      final state =
          DraftReviewState.fromParseResult(result, rawInputText: '벤로막 두 잔');
      expect(state.source, 'local_parser');
      expect(state.entries.length, 1);
      expect(state.foodItems, ['육회']);
      expect(state.place, '바');
      expect(state.rawInputText, '벤로막 두 잔');
    });

    test('toSaveable creates DrinkLog', () {
      final vm = DraftReviewViewModel(DraftReviewState.manual());
      vm.updateEntry(
          0,
          DraftEntry(
            liquorNameRaw: '글렌피딕',
            liquorCategory: 'whisky',
            quantityValue: 2,
            quantityUnit: 'glass',
          ));
      vm.updatePlace('집');
      vm.addFood('치즈');

      final log = vm.toSaveable();
      expect(log.entries.length, 1);
      expect(log.entries.first.liquorNameRaw, '글렌피딕');
      expect(log.place, '집');
      expect(log.foodItems, ['치즈']);
      expect(log.userConfirmedAt, isNotNull);
    });
  });
}
