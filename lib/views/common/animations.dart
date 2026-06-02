import 'package:flutter/material.dart';

/// 강의(위젯 생명주기 / 암시적 애니메이션 / 페이지 전환) 기반 재사용 애니메이션 헬퍼.
///
/// 모두 reduce-motion 접근성(`MediaQuery.disableAnimations`)을 존중해 비활성 시
/// 즉시 정적 렌더로 폴백한다.

/// 리스트 아이템 등장 애니메이션 — fade + slide-up.
///
/// `AnimationController` 수명 관리 없이 1회 진입 애니를 처리하는 TweenAnimationBuilder
/// 라 저위험. `ListView` 가 아이템을 lazily 빌드하므로 스크롤로 진입하는 항목마다
/// 자연스럽게 애니메이션된다.
class AppearAnimation extends StatelessWidget {
  const AppearAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.offsetY = 14,
  });

  final Widget child;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        final v = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * offsetY),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// 화면 전환용 fade + 살짝 위로 미는 커스텀 라우트.
///
/// 기본 `MaterialPageRoute`(플랫폼 슬라이드) 대신 부드러운 fade-through 느낌을
/// 준다. 강의의 "커스텀 페이지 전환 애니메이션"(PageRouteBuilder) 적용.
Route<T> fadeSlideRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
