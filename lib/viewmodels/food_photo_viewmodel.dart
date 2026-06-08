import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../integrations/parser/food_photo_parser.dart';

final foodPhotoOrchestratorProvider = Provider<FoodPhotoOrchestrator>((ref) {
  return FoodPhotoOrchestrator(
    aiConfigRepo: ref.watch(aiConfigRepoProvider),
    parseJobRepo: ref.watch(parseJobRepoProvider),
  );
});

/// View 가 직접 분기하는 reason (integrations enum 비노출 — ARCH 의존성 방향).
enum FoodPhotoUiReason { success, empty, aiDisabled, failed, cancelled }

class FoodPhotoUiResult {
  final FoodPhotoUiReason reason;
  final List<String> foods;

  const FoodPhotoUiResult(this.reason, [this.foods = const []]);
}

FoodPhotoUiReason _mapReason(FoodPhotoReason r) => switch (r) {
      FoodPhotoReason.success => FoodPhotoUiReason.success,
      FoodPhotoReason.empty => FoodPhotoUiReason.empty,
      FoodPhotoReason.aiDisabled => FoodPhotoUiReason.aiDisabled,
      FoodPhotoReason.failed => FoodPhotoUiReason.failed,
    };

/// 음식 사진을 AI(Gemini 비전)로 분석해 음식명 리스트를 추출한다.
/// AI 키 미연결 시 reason=aiDisabled 로 반환 (호출부에서 키 연결 안내).
Future<FoodPhotoUiResult> extractFoodsFromPhoto(
  WidgetRef ref,
  String imagePath,
) async {
  final orchestrator = ref.read(foodPhotoOrchestratorProvider);
  try {
    final result = await orchestrator.extract(imagePath: imagePath);
    return FoodPhotoUiResult(_mapReason(result.reason), result.foods);
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      return const FoodPhotoUiResult(FoodPhotoUiReason.cancelled);
    }
    rethrow;
  }
}
