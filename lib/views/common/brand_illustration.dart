import 'package:flutter/material.dart';

/// 브랜드 빈 상태 일러스트 — CustomPainter 기반 (외부 asset/의존성 없음).
///
/// 위스키 컨셉의 간결한 라인 일러스트. 다크모드 대응(테마 색 사용),
/// 어떤 크기에서도 선명. variant 로 빈 상태 종류 구분.
enum AlbiIllustration { emptyGlass, emptyArchive, emptyStats, welcome, search }

class BrandIllustration extends StatelessWidget {
  const BrandIllustration({
    super.key,
    required this.variant,
    this.size = 120,
  });

  final AlbiIllustration variant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 장식 요소 — 옆 텍스트가 의미를 전달하므로 스크린리더에서 제외.
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _IllustrationPainter(
            variant: variant,
            stroke: scheme.primary,
            fill: scheme.primary.withValues(alpha: 0.12),
            muted: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({
    required this.variant,
    required this.stroke,
    required this.fill,
    required this.muted,
  });

  final AlbiIllustration variant;
  final Color stroke;
  final Color fill;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.022
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final solid = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final mutedLine = Paint()
      ..color = muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round;

    switch (variant) {
      case AlbiIllustration.emptyGlass:
      case AlbiIllustration.welcome:
        _glass(canvas, w, h, line, solid,
            filled: variant == AlbiIllustration.welcome);
        break;
      case AlbiIllustration.emptyArchive:
        _shelf(canvas, w, h, line, solid);
        break;
      case AlbiIllustration.emptyStats:
        _chart(canvas, w, h, line, solid, mutedLine);
        break;
      case AlbiIllustration.search:
        _search(canvas, w, h, line, mutedLine);
        break;
    }
  }

  /// 텀블러 글래스 (welcome 이면 앰버 액체 채움).
  void _glass(Canvas canvas, double w, double h, Paint line, Paint solid,
      {required bool filled}) {
    final cx = w / 2;
    final topY = h * 0.22;
    final botY = h * 0.80;
    final topHalf = w * 0.20;
    final botHalf = w * 0.16;
    final body = Path()
      ..moveTo(cx - topHalf, topY)
      ..lineTo(cx + topHalf, topY)
      ..lineTo(cx + botHalf, botY)
      ..lineTo(cx - botHalf, botY)
      ..close();
    if (filled) {
      final liqTop = topY + (botY - topY) * 0.45;
      final t = (liqTop - topY) / (botY - topY);
      final liqHalf = topHalf + (botHalf - topHalf) * t;
      final liquid = Path()
        ..moveTo(cx - liqHalf, liqTop)
        ..lineTo(cx + liqHalf, liqTop)
        ..lineTo(cx + botHalf, botY)
        ..lineTo(cx - botHalf, botY)
        ..close();
      // 액체 = 테마 primary (light amber / dark cask gold) — 다크 패리티 확보.
      canvas.drawPath(liquid, Paint()..color = stroke.withValues(alpha: 0.55));
    }
    canvas.drawPath(body, solid);
    canvas.drawPath(body, line);
    // 림 타원
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, topY), width: topHalf * 2, height: h * 0.06),
      line,
    );
  }

  /// 선반 + 병 3개 (아카이브).
  void _shelf(Canvas canvas, double w, double h, Paint line, Paint solid) {
    final shelfY = h * 0.74;
    canvas.drawLine(Offset(w * 0.18, shelfY), Offset(w * 0.82, shelfY), line);
    final positions = [0.30, 0.50, 0.70];
    final heights = [0.30, 0.22, 0.34];
    for (var i = 0; i < positions.length; i++) {
      final x = w * positions[i];
      final bottleH = h * heights[i];
      final top = shelfY - bottleH;
      final bw = w * 0.07;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - bw, top + bottleH * 0.28, x + bw, shelfY),
        Radius.circular(w * 0.02),
      );
      canvas.drawRRect(rect, solid);
      canvas.drawRRect(rect, line);
      // 병목
      canvas.drawLine(
          Offset(x, top), Offset(x, top + bottleH * 0.28), line);
    }
  }

  /// 막대 차트 (통계).
  void _chart(Canvas canvas, double w, double h, Paint line, Paint solid,
      Paint mutedLine) {
    final baseY = h * 0.78;
    final axisX = w * 0.20;
    canvas.drawLine(Offset(axisX, h * 0.20), Offset(axisX, baseY), mutedLine);
    canvas.drawLine(Offset(axisX, baseY), Offset(w * 0.82, baseY), mutedLine);
    final bars = [0.30, 0.55, 0.40, 0.68];
    final bw = w * 0.10;
    for (var i = 0; i < bars.length; i++) {
      final x = axisX + w * 0.10 + i * (bw + w * 0.04);
      final top = baseY - (baseY - h * 0.24) * bars[i];
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(x, top, x + bw, baseY),
        topLeft: Radius.circular(w * 0.015),
        topRight: Radius.circular(w * 0.015),
      );
      canvas.drawRRect(rect, solid);
      canvas.drawRRect(rect, line);
    }
  }

  /// 돋보기 (검색 빈 결과).
  void _search(Canvas canvas, double w, double h, Paint line, Paint mutedLine) {
    final c = Offset(w * 0.44, h * 0.42);
    final r = w * 0.18;
    canvas.drawCircle(c, r, line);
    canvas.drawLine(
      Offset(c.dx + r * 0.72, c.dy + r * 0.72),
      Offset(w * 0.74, h * 0.74),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter old) =>
      old.variant != variant ||
      old.stroke != stroke ||
      old.fill != fill ||
      old.muted != muted;
}
