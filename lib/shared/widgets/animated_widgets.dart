import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Scales slightly on press for tactile click feedback.
class TapScale extends StatefulWidget {
  const TapScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
    this.borderRadius,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 150),
    value: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.animateTo(
      widget.scale,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
    );
    await _controller.animateTo(
      1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutBack,
    );
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(20);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _controller.value,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap == null ? null : _handleTap,
          onLongPress: widget.onLongPress,
          borderRadius: radius,
          splashColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          highlightColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fade + slight upward slide when first shown.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 340),
    this.offset = 14,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final totalMs = duration.inMilliseconds + delay.inMilliseconds;
        final delayMs = delay.inMilliseconds;
        final t = totalMs == 0
            ? 1.0
            : ((value * totalMs - delayMs) / duration.inMilliseconds)
                .clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * offset),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Soft page transition used by go_router.
CustomTransitionPage<T> appFadePage<T>({
  required LocalKey key,
  required Widget child,
  bool opaque = true,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    opaque: opaque,
    barrierDismissible: !opaque,
    barrierColor: opaque ? null : Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: opaque ? const Offset(0.025, 0.01) : const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
