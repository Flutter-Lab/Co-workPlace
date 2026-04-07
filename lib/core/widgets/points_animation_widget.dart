import 'package:coworkplace/core/providers/points_animation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Floating "+N pts ⭐" animation that rises and fades out.
/// Place this as an overlay in the app root Stack.
class PointsAnimationWidget extends ConsumerStatefulWidget {
  const PointsAnimationWidget({super.key});

  @override
  ConsumerState<PointsAnimationWidget> createState() =>
      _PointsAnimationWidgetState();
}

class _PointsAnimationWidgetState extends ConsumerState<PointsAnimationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _translateY;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _translateY = Tween<double>(
      begin: 0,
      end: -60,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.6,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(pointsAnimationProvider);

    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward(from: 0.0);
        }
      });
    }

    if (message == null && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.3),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(0, _translateY.value),
                child: Transform.scale(scale: _scale.value, child: child),
              ),
            );
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withAlpha(100),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message ?? '',
                    style: const TextStyle(
                      color: Color(0xFF92400E),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
