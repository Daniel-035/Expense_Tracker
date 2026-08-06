import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../l10n/app_l10n.dart';
import '../theme/app_colors.dart';

/// Shows a short animated overlay, signs out, then lets the router fade to login.
Future<void> performSmoothLogout(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = ref.read(l10nProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.signOutConfirm),
      content: Text(l10n.signOutBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.logout),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: l10n.signingOut,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: Center(
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: AppColors.azure,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.signingOut,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  try {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await ref.read(authRepositoryProvider).logout();
    ref.invalidate(authStateProvider);
    await Future<void>.delayed(const Duration(milliseconds: 220));
  } finally {
    if (context.mounted) {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    }
  }
}
