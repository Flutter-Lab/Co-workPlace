import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoteAnnouncement {
  const VoteAnnouncement({required this.text, required this.color});
  final String text;
  final Color color;
}

class VoteTickerNotifier extends StateNotifier<VoteAnnouncement?> {
  VoteTickerNotifier() : super(null);
  Timer? _clear;

  void announce(
    String text, {
    Color? color,
    Duration duration = const Duration(seconds: 4),
  }) {
    _clear?.cancel();
    state = VoteAnnouncement(text: text, color: color ?? Colors.pink);
    _clear = Timer(duration, () {
      state = null;
    });
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }
}

final voteTickerProvider =
    StateNotifierProvider<VoteTickerNotifier, VoteAnnouncement?>(
      (ref) => VoteTickerNotifier(),
    );
