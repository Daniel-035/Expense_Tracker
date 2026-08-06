import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/app_l10n.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/auth_actions.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../settings/data/settings_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _editing = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final profile = ref.read(authStateProvider).asData?.value;
    final l10n = ref.read(l10nProvider);
    final backend = ref.read(appBackendProvider);
    if (backend.isDemo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.isHindi
                  ? 'डेमो मोड में स्टोरेज उपलब्ध नहीं है'
                  : 'Storage is not available in demo mode',
            ),
          ),
        );
      }
      return;
    }
    final uid = backend.auth?.currentUser?.uid;
    if (profile == null || uid == null) return;

    setState(() => _uploading = true);
    try {
      final url = await ref.read(storageServiceProvider).uploadProfilePhoto(uid);
      await ref.read(profileRepositoryProvider).update(
            profile.copyWith(profilePhoto: url),
          );
      ref.invalidate(authStateProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.photoUpdated)),
        );
      }
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.photoFailed}: ${e.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.photoFailed}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authStateProvider).asData?.value;
    final settings = ref.watch(settingsProvider).asData?.value;
    final l10n = ref.watch(l10nProvider);

    if (profile != null && !_editing) {
      _name.text = profile.name;
      _phone.text = profile.phone ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined),
            onPressed: () async {
              if (_editing && profile != null) {
                await ref.read(profileRepositoryProvider).update(
                      profile.copyWith(
                        name: _name.text.trim(),
                        phone: _phone.text.trim().isEmpty
                            ? null
                            : _phone.text.trim(),
                      ),
                    );
              }
              setState(() => _editing = !_editing);
            },
          ),
        ],
      ),
      body: profile == null
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundImage: profile.profilePhoto != null &&
                                profile.profilePhoto!.isNotEmpty
                            ? NetworkImage(profile.profilePhoto!)
                            : null,
                        child: profile.profilePhoto == null ||
                                profile.profilePhoto!.isEmpty
                            ? Text(
                                profile.name.isNotEmpty
                                    ? profile.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 32),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _uploading ? null : _changePhoto,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: _uploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _uploading ? null : _changePhoto,
                    child: Text(l10n.uploadPhoto),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  enabled: _editing,
                  decoration: InputDecoration(labelText: l10n.name),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: profile.email,
                  enabled: false,
                  decoration: InputDecoration(labelText: l10n.email),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  enabled: _editing,
                  decoration: InputDecoration(labelText: l10n.phone),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.currency),
                  subtitle: Text(settings?.currency ?? profile.currency),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.language),
                  subtitle: Text(
                    (settings?.language ?? profile.language) == 'hi'
                        ? l10n.hindi
                        : l10n.english,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.timezone),
                  subtitle: Text(profile.timezone),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(l10n.navAccounts),
                  onTap: () => context.go('/accounts'),
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(l10n.navCategories),
                  onTap: () => context.go('/categories'),
                ),
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(l10n.navBills),
                  onTap: () => context.go('/bills'),
                ),
                ListTile(
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(l10n.navGoals),
                  onTap: () => context.go('/goals'),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(l10n.navCalendar),
                  onTap: () => context.go('/calendar'),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(l10n.settings),
                  onTap: () => context.go('/settings'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.logout),
                  onTap: () => performSmoothLogout(context, ref),
                ),
              ],
            ),
    );
  }
}
