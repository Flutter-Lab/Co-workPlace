import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coworkplace/core/providers/vote_ticker_provider.dart';

class VoteTicker extends ConsumerStatefulWidget {
  const VoteTicker({super.key});

  @override
  ConsumerState<VoteTicker> createState() => _VoteTickerState();
}

class _VoteTickerState extends ConsumerState<VoteTicker>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    // Intentionally left empty — animation is started from build when announcements change.
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _startAnimation() {
    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
  }

  @override
  Widget build(BuildContext context) {
    final announcement = ref.watch(voteTickerProvider);
    if (announcement == null) return const SizedBox.shrink();

    // start/reset animation whenever announcement changes
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());

    final text = announcement.text;
    final color = announcement.color;

    return SizedBox(
      height: 36,
      child: ClipRect(
        child: ColoredBox(
          color: color.withAlpha(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                const Icon(Icons.campaign, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _controller ?? kAlwaysDismissedAnimation,
                    builder: (context, child) {
                      final progress = (_controller?.value ?? 0.0);
                      final offset = Tween(
                        begin: 1.0,
                        end: -1.0,
                      ).transform(progress);
                      return Transform.translate(
                        offset: Offset(
                          offset * MediaQuery.of(context).size.width,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: Text(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
