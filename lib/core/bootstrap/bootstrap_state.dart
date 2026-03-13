class BootstrapState {
  const BootstrapState({required this.firebaseReady, this.errorMessage});

  final bool firebaseReady;
  final String? errorMessage;
}
