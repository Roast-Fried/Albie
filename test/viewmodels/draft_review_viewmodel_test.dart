import 'package:flutter_test/flutter_test.dart';
import 'package:albi/viewmodels/draft_review_viewmodel.dart';

void main() {
  DraftReviewState makeState({String? place, String? overallMemo}) {
    return DraftReviewState(
      source: 'manual',
      drankAt: DateTime(2026, 5, 18, 21, 30),
      place: place,
      overallMemo: overallMemo,
    );
  }

  group('DraftReviewState.copyWith — sentinel nullable clear', () {
    test('copyWith(place: null) explicitly clears place', () {
      final state = makeState(place: '바', overallMemo: '괜찮음');
      final cleared = state.copyWith(place: null);

      expect(cleared.place, isNull);
      // 다른 필드는 영향 없음
      expect(cleared.overallMemo, '괜찮음');
    });

    test('copyWith(overallMemo: null) explicitly clears memo', () {
      final state = makeState(place: '집', overallMemo: '졸림');
      final cleared = state.copyWith(overallMemo: null);

      expect(cleared.overallMemo, isNull);
      expect(cleared.place, '집');
    });

    test('copyWith() without place arg preserves existing place', () {
      // sentinel 핵심 — 인자 미지정 시 null 로 덮어쓰면 안 됨
      final state = makeState(place: '바', overallMemo: '좋음');
      final modified = state.copyWith(drankAt: DateTime(2026, 5, 19));

      expect(modified.place, '바');
      expect(modified.overallMemo, '좋음');
      expect(modified.drankAt.day, 19);
    });

    test('copyWith(place: "값") 정상 업데이트', () {
      final state = makeState(place: '집');
      final modified = state.copyWith(place: '술집');

      expect(modified.place, '술집');
    });

    test('null clear → 값 재설정 → 다시 clear 라운드트립', () {
      final initial = makeState(place: '바');
      final cleared = initial.copyWith(place: null);
      final reset = cleared.copyWith(place: '집');
      final reCleared = reset.copyWith(place: null);

      expect(initial.place, '바');
      expect(cleared.place, isNull);
      expect(reset.place, '집');
      expect(reCleared.place, isNull);
    });
  });
}
