import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';

/// AI(Gemini 비전) 전송용으로 준비된 이미지 — 리사이즈 + PNG 재인코딩 결과.
class PreparedAiImage {
  final Uint8List bytes;
  final String mimeType;

  const PreparedAiImage({required this.bytes, required this.mimeType});
}

/// 이미지 파일을 읽어 최대 변 [maxSide] 로 리사이즈 후 PNG 로 재인코딩한다.
/// [path] 가 null/빈 문자열이면 null 반환. [cancelToken] 취소 시 즉시 throw.
///
/// 텍스트 파서(술 라벨/영수증)와 음식 사진 파서가 공용으로 사용한다.
Future<PreparedAiImage?> prepareImageForAi(
  String? path, {
  CancelToken? cancelToken,
  int maxSide = 1600,
}) async {
  if (path == null || path.isEmpty) return null;

  _throwIfCancelled(cancelToken);
  final originalBytes = await XFile(path).readAsBytes();
  _throwIfCancelled(cancelToken);
  final buffer = await ui.ImmutableBuffer.fromUint8List(originalBytes);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? decoded;

  try {
    _throwIfCancelled(cancelToken);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longestSide = math.max(descriptor.width, descriptor.height);
    final scale = longestSide > maxSide ? maxSide / longestSide : 1.0;
    final targetWidth = math.max(1, (descriptor.width * scale).round());
    final targetHeight = math.max(1, (descriptor.height * scale).round());

    _throwIfCancelled(cancelToken);
    codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    decoded = frame.image;
    _throwIfCancelled(cancelToken);
    final data = await decoded.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw Exception('이미지를 AI 전송용으로 변환하지 못했습니다');
    }

    final bytes = Uint8List.fromList(data.buffer.asUint8List());
    return PreparedAiImage(bytes: bytes, mimeType: 'image/png');
  } finally {
    decoded?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// CancelToken 이 취소 상태면 즉시 throw — decode/resize 루프 사이에서 호출.
/// Dio 의 cancelError 를 그대로 던져 상위 retry/rethrow 로직과 호환.
void _throwIfCancelled(CancelToken? token) {
  if (token == null || !token.isCancelled) return;
  final err = token.cancelError;
  if (err != null) throw err;
  throw DioException.requestCancelled(
    requestOptions: RequestOptions(path: ''),
    reason: 'image preparation cancelled',
  );
}
