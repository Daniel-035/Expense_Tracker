import '../../../../core/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/device_lock.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/utils/auth_actions.dart';
import '../../../../core/utils/export_actions.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/settings_repository.dart';
import '../../domain/app_settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsProvider).asData?.value ?? const AppSettings();
    final backend = ref.watch(appBackendProvider);
    final uid = ref.read(appBackendProvider).isDemo
        ? ref.read(demoStoreProvider).sessionUser?.id
        : ref.read(appBackendProvider).auth?.currentUser?.uid;
    final lockAsync = uid == null
        ? const AsyncData(DeviceLock())
        : ref.watch(deviceLockProvider(uid));
    final lock = lockAsync.asData?.value ?? const DeviceLock();
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.appearance), dense: true),
          RadioListTile<String>(
            title: Text(l10n.system),
            value: 'system',
            // ignore: deprecated_member_use
            groupValue: settings.theme,
            // ignore: deprecated_member_use
            onChanged: (v) => _update(ref, settings.copyWith(theme: v)),
          ),
          RadioListTile<String>(
            title: Text(l10n.light),
            value: 'light',
            // ignore: deprecated_member_use
            groupValue: settings.theme,
            // ignore: deprecated_member_use
            onChanged: (v) => _update(ref, settings.copyWith(theme: v)),
          ),
          RadioListTile<String>(
            title: Text(l10n.dark),
            value: 'dark',
            // ignore: deprecated_member_use
            groupValue: settings.theme,
            // ignore: deprecated_member_use
            onChanged: (v) => _update(ref, settings.copyWith(theme: v)),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.notifications_none),
            title: AppText('Bill reminders'),
            subtitle: Text(
              'Upcoming and overdue bills are shown on Home. Push notifications are not enabled.',
            ),
          ),
          SwitchListTile(
            title: Text(l10n.biometric),
            subtitle: const Text(
              'Device authentication on open and after backgrounding',
            ),
            value: lock.biometric,
            onChanged: uid == null || !lockAsync.hasValue
                ? null
                : (v) async {
                    try {
                      final service = ref.read(deviceLockServiceProvider);
                      if (!await service.biometric()) return;
                      await service.write(
                        uid,
                        DeviceLock(pin: lock.pin, biometric: v),
                      );
                      ref.invalidate(deviceLockProvider(uid));
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$error')));
                      }
                    }
                  },
          ),
          SwitchListTile(
            title: Text(l10n.pinLock),
            subtitle: const AppText(
              'Applies only to this account on this device',
            ),
            value: lock.pin != null,
            onChanged: uid == null || !lockAsync.hasValue
                ? null
                : (v) async {
                    try {
                      if (!v) {
                        final entered = await _askPin(
                          context,
                          title: 'Enter current PIN',
                        );
                        if (entered != lock.pin) {
                          throw StateError('Incorrect PIN.');
                        }
                      }
                      if (!context.mounted) return;
                      final pin = v ? await _askPin(context) : null;
                      if (v && pin == null) return;
                      if (v) {
                        if (!context.mounted) return;
                        final repeated = await _askPin(
                          context,
                          title: 'Confirm PIN',
                        );
                        if (repeated != pin) {
                          throw StateError('PINs do not match.');
                        }
                      }
                      await ref
                          .read(deviceLockServiceProvider)
                          .write(
                            uid,
                            DeviceLock(pin: pin, biometric: lock.biometric),
                          );
                      ref.invalidate(deviceLockProvider(uid));
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('$error')));
                      }
                    }
                  },
          ),
          const Divider(),
          ListTile(
            title: Text(ref.watch(l10nProvider).language),
            subtitle: Text(
              settings.language == 'hi'
                  ? ref.watch(l10nProvider).hindi
                  : ref.watch(l10nProvider).english,
            ),
            leading: const Icon(Icons.translate),
            onTap: () async {
              final l10n = ref.read(l10nProvider);
              final selected = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: Text(l10n.language),
                  children: [
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 'en'),
                      child: Text(l10n.english),
                    ),
                    SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, 'hi'),
                      child: Text(l10n.hindi),
                    ),
                  ],
                ),
              );
              if (selected != null) {
                await _update(ref, settings.copyWith(language: selected));
              }
            },
          ),
          ListTile(
            title: Text(ref.watch(l10nProvider).currency),
            subtitle: Text(
              '${settings.currency} - ledger currency; changing it does not convert amounts',
            ),
            onTap: () async {
              final currencies = ['INR', 'USD', 'EUR', 'GBP'];
              final selected = await showDialog<String>(
                context: context,
                builder: (ctx) => SimpleDialog(
                  title: Text(ref.read(l10nProvider).currency),
                  children: currencies
                      .map(
                        (c) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(ctx, c),
                          child: Text(c),
                        ),
                      )
                      .toList(),
                ),
              );
              if (selected != null) {
                await _update(ref, settings.copyWith(currency: selected));
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(ref.watch(l10nProvider).exportData),
            subtitle: Text(ref.watch(l10nProvider).downloadActivityHint),
            onTap: () => showExportShareSheet(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: const AppText('Backup / sync'),
            subtitle: Text(
              backend.isDemo
                  ? 'Demo mode stores data locally on this device'
                  : 'Cloud storage enabled. Posting money changes requires a connection.',
            ),
          ),
          _DeleteAccountTile(backend: backend, l10n: l10n),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.logout),
            onTap: () => performSmoothLogout(context, ref),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'LedgerOne v1.0 · ${backend.isDemo ? 'Demo' : 'Firebase'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _update(WidgetRef ref, AppSettings settings) async {
    try {
      await ref.read(settingsRepositoryProvider).update(settings);
    } catch (error) {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(
          ref.context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<String?> _askPin(
    BuildContext context, {
    String title = 'Set PIN',
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            labelText: AppText.translate(context, '4–6 digit PIN'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (RegExp(r'^\d{4,6}$').hasMatch(controller.text)) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _DeleteAccountTile extends ConsumerStatefulWidget {
  const _DeleteAccountTile({required this.backend, required this.l10n});

  final AppBackend backend;
  final AppL10n l10n;

  @override
  ConsumerState<_DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<_DeleteAccountTile> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: Icon(Icons.delete_forever, color: errorColor),
      title: Text(
        widget.l10n.deleteAccount,
        style: TextStyle(color: errorColor),
      ),
      subtitle: Text(
        widget.backend.isDemo
            ? 'Clears all demo data stored on this device'
            : 'Permanently deletes Firebase data, uploaded files, and sign-in',
      ),
      trailing: _deleting
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : null,
      enabled: !_deleting,
      onTap: _deleting ? null : _confirmAndDelete,
    );
  }

  Future<void> _confirmAndDelete() async {
    final phraseController = TextEditingController();
    final passwordController = TextEditingController();
    final requiresPassword =
        !widget.backend.isDemo &&
        (widget.backend.auth?.currentUser?.providerData.any(
              (provider) => provider.providerId == 'password',
            ) ??
            false);

    final confirmation = await showDialog<_DeleteConfirmation>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final confirmed = phraseController.text.trim() == 'DELETE';
            return AlertDialog(
              title: Text(widget.l10n.deleteAccount),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.l10n.isHindi
                          ? 'यह आपके सभी LedgerOne डेटा, रसीदें और साइन-इन को स्थायी रूप से हटा देता है।'
                          : 'This permanently deletes all LedgerOne data, receipts, and sign-in access.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phraseController,
                      decoration: const InputDecoration(
                        labelText: 'Type DELETE to confirm',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (requiresPassword) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Current password',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(widget.l10n.cancel),
                ),
                FilledButton(
                  onPressed: confirmed
                      ? () => Navigator.pop(
                          dialogContext,
                          _DeleteConfirmation(passwordController.text),
                        )
                      : null,
                  child: Text(widget.l10n.delete),
                ),
              ],
            );
          },
        );
      },
    );
    phraseController.dispose();
    passwordController.dispose();
    if (confirmation == null || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .deleteAccount(password: confirmation.password);
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account deletion failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }
}

class _DeleteConfirmation {
  const _DeleteConfirmation(this.password);

  final String password;
}
