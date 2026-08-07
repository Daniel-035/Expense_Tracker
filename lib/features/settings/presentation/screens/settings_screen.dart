import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

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
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.appearance),
            dense: true,
          ),
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
          SwitchListTile(
            title: Text(l10n.notifications),
            value: settings.notifications,
            onChanged: (v) =>
                _update(ref, settings.copyWith(notifications: v)),
          ),
          SwitchListTile(
            title: Text(l10n.biometric),
            subtitle: Text(l10n.biometricHint),
            value: settings.biometric,
            onChanged: (v) async {
              if (v) {
                final auth = LocalAuthentication();
                final ok = await auth.authenticate(
                  localizedReason: l10n.biometricHint,
                );
                if (!ok) return;
              }
              await _update(ref, settings.copyWith(biometric: v));
            },
          ),
          SwitchListTile(
            title: Text(l10n.pinLock),
            value: settings.pinEnabled,
            onChanged: (v) async {
              if (v) {
                final pin = await _askPin(context);
                if (pin == null) return;
                const storage = FlutterSecureStorage();
                await storage.write(key: 'ledgerone_pin', value: pin);
              }
              await _update(ref, settings.copyWith(pinEnabled: v));
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
            subtitle: Text(settings.currency),
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
            title: const Text('Backup / sync'),
            subtitle: Text(
              backend.isDemo
                  ? 'Demo mode stores data locally on this device'
                  : 'Synced automatically via Firebase',
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

  Future<void> _update(WidgetRef ref, AppSettings settings) {
    return ref.read(settingsRepositoryProvider).update(settings);
  }

  Future<String?> _askPin(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '4–6 digit PIN'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountTile extends ConsumerStatefulWidget {
  const _DeleteAccountTile({required this.backend, required this.l10n});

  final AppBackend backend;
  final AppL10n l10n;

  @override
  ConsumerState<_DeleteAccountTile> createState() =>
      _DeleteAccountTileState();
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
