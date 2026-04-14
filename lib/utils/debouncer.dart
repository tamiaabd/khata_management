import 'dart:async';

class Debouncer {
  Debouncer({required this.duration});

  final Duration duration;
  Timer? _timer;
  void Function()? _pendingAction;

  void run(void Function() action) {
    _pendingAction = action;
    _timer?.cancel();
    _timer = Timer(duration, () {
      _pendingAction = null;
      action();
    });
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final action = _pendingAction;
    _pendingAction = null;
    if (action != null) action();
  }

  void dispose() {
    _timer?.cancel();
  }
}
