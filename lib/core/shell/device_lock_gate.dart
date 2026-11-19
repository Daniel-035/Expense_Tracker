import '../l10n/app_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_repository.dart';
import '../services/device_lock.dart';
import '../../shared/widgets/async_action_button.dart';

class DeviceLockGate extends ConsumerStatefulWidget {
  const DeviceLockGate({super.key, required this.uid, required this.child});
  final String uid;
  final Widget child;
  @override
  ConsumerState<DeviceLockGate> createState() => _DeviceLockGateState();
}

class _DeviceLockGateState extends ConsumerState<DeviceLockGate>
    with WidgetsBindingObserver {
  final _pin = TextEditingController();
  bool _unlocked = false;
  String? _error;
  int _attempts = 0;
  DateTime? _retryAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      setState(() {
        _unlocked = false;
        _pin.clear();
      });
    }
  }

  Future<void> _unlock(DeviceLock lock, {bool biometric = false}) async {
    if (_retryAt != null && DateTime.now().isBefore(_retryAt!)) return;
    try {
      final ok = biometric
          ? await ref.read(deviceLockServiceProvider).biometric()
          : lock.pin != null && _pin.text == lock.pin;
      if (!mounted) return;
      if (ok) {
        setState(() {
          _unlocked = true;
          _attempts = 0;
          _error = null;
          _pin.clear();
        });
      } else {
        setState(() {
          _attempts++;
          _error = 'Could not unlock. Try again.';
          _pin.clear();
          if (_attempts >= 5) {
            _retryAt = DateTime.now().add(const Duration(seconds: 30));
            _error = 'Too many attempts. Wait 30 seconds.';
            _timer?.cancel();
            _timer = Timer(const Duration(seconds: 30), () {
              if (mounted) {
                setState(() {
                  _retryAt = null;
                  _attempts = 0;
                  _error = null;
                });
              }
            });
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockAsync = ref.watch(deviceLockProvider(widget.uid));
    return lockAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText('Could not read device lock settings.'),
              TextButton(
                onPressed: () => ref.invalidate(deviceLockProvider(widget.uid)),
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (lock) {
        final locked = lock.enabled && !_unlocked;
        final screen = Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const AppText('Unlock LedgerOne'),
                    if (lock.pin != null)
                      TextField(
                        controller: _pin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'PIN'),
                        onSubmitted: (_) => _unlock(lock),
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (lock.pin != null)
                      AsyncActionButton(
                        onPressed: _retryAt != null
                            ? null
                            : () => _unlock(lock),
                        child: const AppText('Unlock'),
                      ),
                    if (lock.biometric)
                      AsyncActionButton(
                        onPressed: _retryAt != null
                            ? null
                            : () => _unlock(lock, biometric: true),
                        child: const AppText('Use device authentication'),
                      ),
                    AsyncActionButton(
                      onPressed: () async {
                        // Recovery requires a fresh account sign-in before data is accessible.
                        final service = ref.read(deviceLockServiceProvider);
                        await ref.read(authRepositoryProvider).logout();
                        await service.clear(widget.uid);
                        if (mounted) {
                          ref.invalidate(deviceLockProvider(widget.uid));
                        }
                      },
                      child: const AppText(
                        'Forgot PIN? Sign out and reset lock',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return Stack(
          children: [
            Offstage(
              offstage: locked,
              child: ExcludeFocus(
                excluding: locked,
                child: TickerMode(enabled: !locked, child: widget.child),
              ),
            ),
            if (locked) Positioned.fill(child: screen),
          ],
        );
      },
    );
  }
}
