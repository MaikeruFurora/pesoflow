import 'package:quick_actions/quick_actions.dart';

/// Routes launcher-shortcut events into a single buffer that survives across
/// widget lifecycles. quick_actions invokes its callback on cold-launch as
/// soon as the activity attaches — well before HomeShell exists (lock screen
/// may still be showing). Buffering the action here keeps it alive until the
/// dashboard mounts and asks for it.
class QuickActionDispatcher {
  QuickActionDispatcher._();
  static final instance = QuickActionDispatcher._();

  final QuickActions _q = const QuickActions();
  String? _pending;
  bool _started = false;

  void Function(String type)? _listener;

  /// Called once from `main()` before runApp. Registers shortcuts and the
  /// callback that captures the launch type.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _q.initialize((type) {
      _pending = type;
      _listener?.call(type);
    });
    await _q.setShortcutItems(const [
      ShortcutItem(
        type: 'action_add_expense',
        localizedTitle: 'Add expense',
        icon: 'ic_shortcut_expense',
      ),
      ShortcutItem(
        type: 'action_save_goal',
        localizedTitle: 'Save to goal',
        icon: 'ic_shortcut_goal',
      ),
      ShortcutItem(
        type: 'action_transfer',
        localizedTitle: 'Transfer',
        icon: 'ic_shortcut_transfer',
      ),
    ]);
  }

  /// Consume + return any buffered shortcut. HomeShell calls this on init.
  String? takePending() {
    final t = _pending;
    _pending = null;
    return t;
  }

  /// Live listener for warm-launch taps (HomeShell already on-screen).
  set listener(void Function(String type)? l) => _listener = l;
}
