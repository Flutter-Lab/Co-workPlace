import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class PointsAnimationNotifier extends StateNotifier<String?> {
  PointsAnimationNotifier() : super(null);
  Timer? _clear;

  void show(String message, {Duration duration = const Duration(seconds: 2)}) {
    _clear?.cancel();
    state = message;
    _clear = Timer(duration, () => state = null);
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }
}

final pointsAnimationProvider =
    StateNotifierProvider<PointsAnimationNotifier, String?>(
      (ref) => PointsAnimationNotifier(),
    );
