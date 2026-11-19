import 'package:flutter/material.dart';
import '../../core/l10n/app_text.dart';

Future<void> confirmMutation(
  BuildContext context, {
  required String title,
  required Future<void> Function() action,
  String message = 'This action updates your saved data.',
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const AppText('Cancel'),
      ),
      AsyncActionButton(
        onPressed: () async {
          await action();
          if (ctx.mounted) Navigator.pop(ctx);
        },
        child: const AppText('Confirm'),
      ),
    ],
  ),
);

/// Owns mutation state, blocks repeated submissions and surfaces failures.
class AsyncActionButton extends StatefulWidget {
  const AsyncActionButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final Future<void> Function()? onPressed;
  final Widget child;

  @override
  State<AsyncActionButton> createState() => _AsyncActionButtonState();
}

class _AsyncActionButtonState extends State<AsyncActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: _busy || widget.onPressed == null ? null : _run,
    child: _busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : widget.child,
  );
}
