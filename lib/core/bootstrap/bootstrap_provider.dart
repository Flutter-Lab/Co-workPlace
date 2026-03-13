import 'package:coworkplace/core/bootstrap/bootstrap_state.dart';
import 'package:coworkplace/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appBootstrapProvider = FutureProvider<BootstrapState>((ref) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return const BootstrapState(firebaseReady: true);
  } catch (error) {
    return BootstrapState(firebaseReady: false, errorMessage: error.toString());
  }
});
