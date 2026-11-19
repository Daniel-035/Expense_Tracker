import '../../../../core/l10n/app_text.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/recurrence.dart';
import '../../../settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/user_bootstrap.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/rate_limiter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/animated_widgets.dart';
import '../../../accounts/data/accounts_repository.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../categories/domain/category.dart';
import '../../data/transactions_repository.dart';
import '../../domain/money_transaction.dart';

class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.initialType = TransactionType.expense,
    this.transactionId,
  });

  final TransactionType initialType;
  final String? transactionId;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _notes = TextEditingController();
  final _location = TextEditingController();

  late TransactionType _type;
  String? _accountId;
  String? _categoryId;
  DateTime _date = DateTime.now();
  RecurrenceInterval _recurrence = RecurrenceInterval.none;
  bool _loading = false;
  bool _bootstrapping = true;
  MoneyTransaction? _existing;
  String _newId = const Uuid().v4();
  String? _loadError;
  String? _transferAccountId;
  String? _receiptUrl;
  final _tags = TextEditingController();
  bool _uploading = false;
  bool _allowPop = false;
  Timer? _draftTimer;
  bool _saved = false;
  String? _sessionUid;
  String? get _uid => _sessionUid;
  String? get _currentUid => ref.read(appBackendProvider).isDemo
      ? ref.read(demoStoreProvider).sessionUser?.id
      : ref.read(appBackendProvider).auth?.currentUser?.uid;
  String get _draftKey =>
      'ledgerone_draft_${_uid}_${widget.transactionId ?? "new"}';
  bool get _editing =>
      widget.transactionId != null && widget.transactionId != 'new';
  bool get _dirty =>
      _amount.text.isNotEmpty ||
      _merchant.text.isNotEmpty ||
      _notes.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _sessionUid = _currentUid;
    WidgetsBinding.instance.addObserver(this);
    for (final controller in [_amount, _merchant, _notes, _location, _tags]) {
      controller.addListener(() {
        if (_bootstrapping || _editing || _saved) return;
        _draftTimer?.cancel();
        _draftTimer = Timer(const Duration(milliseconds: 400), () {
          _persistDraft().catchError((Object error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: AppText(
                    'Could not save draft on this device. Keep this form open.',
                  ),
                ),
              );
            }
          });
        });
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initialize();
    });
  }

  Future<void> _initialize() async {
    setState(() {
      _bootstrapping = true;
      _loadError = null;
    });
    try {
      try {
        await ref.read(userBootstrapProvider).ensureDefaults();
      } catch (_) {
        /* Cached accounts still allow drafting while offline. */
      }
      if (!mounted) return;
      if (_editing) {
        final found = await ref
            .read(transactionsRepositoryProvider)
            .getById(widget.transactionId!);
        if (!mounted) return;
        if (found == null) throw StateError('Transaction not found.');
        _existing = found;
        _type = found.transactionType;
        _amount.text = found.amount.toStringAsFixed(2);
        _merchant.text = found.merchant ?? '';
        _notes.text = found.notes ?? '';
        _location.text = found.location ?? '';
        _tags.text = found.tags.join(', ');
        _receiptUrl = found.receiptUrl;
        _transferAccountId = found.transferAccountId;
        _accountId = found.accountId;
        _categoryId = found.categoryId;
        _date = found.createdAt;
        _recurrence = found.recurrence;
      } else {
        final prefs = await SharedPreferences.getInstance();
        _accountId = prefs.getString('ledgerone_last_account_$_uid');
        final raw = prefs.getString(_draftKey);
        if (raw != null && mounted) {
          final restore = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const AppText('Restore saved draft?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const AppText('Discard'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const AppText('Restore'),
                ),
              ],
            ),
          );
          if (restore == true) {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            _newId = data['id'] as String? ?? _newId;
            _amount.text = data['amount'] as String? ?? '';
            _merchant.text = data['merchant'] as String? ?? '';
            _notes.text = data['notes'] as String? ?? '';
            _location.text = data['location'] as String? ?? '';
            _tags.text = data['tags'] as String? ?? '';
            _accountId = data['account'] as String?;
            _categoryId = data['category'] as String?;
            _transferAccountId = data['destination'] as String?;
            _receiptUrl = data['receipt'] as String?;
            _date = DateTime.tryParse(data['date'] as String? ?? '') ?? _date;
            _type = TransactionType.values.firstWhere(
              (t) => t.name == data['type'],
              orElse: () => _type,
            );
            _recurrence = RecurrenceInterval.values.firstWhere(
              (r) => r.name == data['recurrence'],
              orElse: () => RecurrenceInterval.none,
            );
          } else {
            await prefs.remove(_draftKey);
          }
        }
      }
    } catch (error) {
      _loadError = '$error';
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _persistDraft().catchError((Object error) {});
    }
  }

  Future<void> _persistDraft() async {
    if (_editing || _uid == null || _saved || _bootstrapping) return;
    final uid = _uid;
    final key = _draftKey;
    final raw = jsonEncode({
      'id': _newId,
      'amount': _amount.text,
      'merchant': _merchant.text,
      'notes': _notes.text,
      'location': _location.text,
      'tags': _tags.text,
      'account': _accountId,
      'category': _categoryId,
      'destination': _transferAccountId,
      'receipt': _receiptUrl,
      'type': _type.name,
      'date': _date.toIso8601String(),
      'recurrence': _recurrence.name,
    });
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _currentUid != uid || _saved) return;
    await prefs.setString(key, raw);
  }

  Future<void> _attachReceipt() async {
    if (_uploading || _loading || _uid == null) return;
    setState(() => _uploading = true);
    try {
      final url = await ref
          .read(storageServiceProvider)
          .uploadReceipt(uid: _uid!, transactionId: _existing?.id ?? _newId);
      if (mounted) setState(() => _receiptUrl = url);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete() async {
    if (_loading || _existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('Delete transaction?'),
        content: const AppText('The account balance will be adjusted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await ref.read(transactionsRepositoryProvider).delete(_existing!.id);
      if (mounted) _exit();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _amount.dispose();
    _merchant.dispose();
    _notes.dispose();
    _location.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_currentUid != _uid ||
        _loading ||
        _bootstrapping ||
        _loadError != null ||
        (_editing && _existing == null)) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null ||
        (_type != TransactionType.transfer && _categoryId == null) ||
        (_type == TransactionType.transfer &&
            (_transferAccountId == null || _transferAccountId == _accountId))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select account and category. If lists are empty, open Accounts / Categories first.',
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _persistDraft();
      if (!mounted || _currentUid != _uid) return;
      final tx = MoneyTransaction(
        id: _existing?.id ?? _newId,
        accountId: _accountId!,
        categoryId: _type == TransactionType.transfer ? '' : _categoryId!,
        transferAccountId: _type == TransactionType.transfer
            ? _transferAccountId
            : null,
        receiptUrl: _receiptUrl,
        tags: _existing != null && _tags.text == _existing!.tags.join(', ')
            ? _existing!.tags
            : _tags.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toSet()
                  .toList(),
        amount: double.parse(_amount.text.trim()),
        transactionType: _type,
        merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        recurrence: _recurrence,
        nextOccurrence: _recurrence == RecurrenceInterval.none
            ? null
            : nextOccurrence(_date, _recurrence),
        createdAt: _date,
      );
      final repo = ref.read(transactionsRepositoryProvider);
      if (_existing == null) {
        await repo.create(tx);
      } else {
        await repo.update(tx);
      }
      if (!mounted) return;
      _saved = true;
      _draftTimer?.cancel();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
      await prefs.setString('ledgerone_last_account_$_uid', _accountId!);
      if (mounted) _exit();
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (!mounted) return;
    setState(() {
      _date = DateTime(
        d.year,
        d.month,
        d.day,
        t?.hour ?? _date.hour,
        t?.minute ?? _date.minute,
      );
    });
  }

  InputDecoration _denseDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: AppText.translate(context, label),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
    );
  }

  Future<void> _close() async {
    if (_loading || _uploading) return;
    if (_dirty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(_editing ? 'Discard changes?' : 'Save draft and close?'),
          content: Text(
            _editing
                ? 'Your changes have not been saved.'
                : 'Your draft stays on this device until you save or discard it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('Close'),
            ),
          ],
        ),
      );
      if (leave != true) return;
      await _persistDraft();
    }
    if (mounted) _exit();
  }

  void _exit() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/transactions');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final catsAsync = ref.watch(categoriesProvider);
    final accounts = (accountsAsync.asData?.value ?? [])
        .where(
          (a) =>
              !a.archived ||
              a.id == _existing?.accountId ||
              a.id == _existing?.transferAccountId,
        )
        .toList();
    final currency =
        ref.watch(settingsProvider).asData?.value.currency ?? 'INR';
    if (_bootstrapping) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null || accountsAsync.hasError || catsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const AppText('Transaction')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError ?? 'Could not load accounts or categories.'),
              TextButton(
                onPressed: () {
                  ref.invalidate(accountsProvider);
                  ref.invalidate(categoriesProvider);
                  _initialize();
                },
                child: const AppText('Retry'),
              ),
              TextButton(onPressed: _exit, child: const AppText('Close')),
            ],
          ),
        ),
      );
    }
    final categories = ref.watch(categoriesProvider).asData?.value ?? const [];
    final filteredCats = categories
        .where(
          (c) =>
              c.type ==
              (_type == TransactionType.income
                  ? CategoryType.income
                  : CategoryType.expense),
        )
        .toList();

    if (!_editing && _accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    } else if (!_editing &&
        _accountId != null &&
        accounts.isNotEmpty &&
        !accounts.any((a) => a.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    if (!_editing && _categoryId == null && filteredCats.isNotEmpty) {
      _categoryId = filteredCats.first.id;
    } else if (!_editing &&
        _categoryId != null &&
        filteredCats.isNotEmpty &&
        !filteredCats.any((c) => c.id == _categoryId)) {
      _categoryId = filteredCats.first.id;
    }

    final isIncome = _type == TransactionType.income;
    final title = _existing == null
        ? (_type == TransactionType.transfer
              ? 'Add transfer'
              : isIncome
              ? 'Add income'
              : 'Add expense')
        : 'Edit transaction';
    final size = MediaQuery.sizeOf(context);
    final maxCardWidth = size.width >= 900
        ? 640.0
        : size.width >= 600
        ? size.width * 0.72
        : size.width * 0.94;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.45),
        body: SafeArea(
          child: Stack(
            children: [
              // Backdrop only — does not wrap the card, so web dropdowns work.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: const SizedBox.expand(),
                ),
              ),
              Center(
                child: FadeSlideIn(
                  offset: 16,
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    elevation: 12,
                    shadowColor: AppColors.azure.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxCardWidth,
                        maxHeight: size.height * 0.92,
                      ),
                      child: SizedBox(
                        width: maxCardWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Header(
                              title: title,
                              isIncome: isIncome,
                              showDelete: _existing != null,
                              onClose: _close,
                              onDelete: _delete,
                            ),
                            if (_bootstrapping)
                              const LinearProgressIndicator(minHeight: 2),
                            Flexible(
                              child: Form(
                                key: _formKey,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    8,
                                    22,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (accounts.isEmpty ||
                                          (_type != TransactionType.transfer &&
                                              filteredCats.isEmpty))
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          child: Text(
                                            accounts.isEmpty
                                                ? 'No accounts yet — creating defaults…'
                                                : 'No categories for this type — creating defaults…',
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                        ),
                                      SegmentedButton<TransactionType>(
                                        style: const ButtonStyle(
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        segments: const [
                                          ButtonSegment(
                                            value: TransactionType.expense,
                                            label: AppText('Expense'),
                                            icon: Icon(
                                              Icons.north_east_rounded,
                                            ),
                                          ),
                                          ButtonSegment(
                                            value: TransactionType.income,
                                            label: AppText('Income'),
                                            icon: Icon(
                                              Icons.south_west_rounded,
                                            ),
                                          ),
                                          ButtonSegment(
                                            value: TransactionType.transfer,
                                            label: AppText('Transfer'),
                                            icon: Icon(Icons.swap_horiz),
                                          ),
                                        ],
                                        selected: {_type},
                                        onSelectionChanged: (s) => setState(() {
                                          _type = s.first;
                                          _categoryId = null;
                                        }),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: _amount,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: isIncome
                                                  ? AppColors.income
                                                  : AppColors.expense,
                                            ),
                                        decoration: InputDecoration(
                                          labelText: 'Amount ($currency)',
                                          hintText: '0.00',
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 14,
                                              ),
                                          prefixIcon: Icon(
                                            currency == 'INR'
                                                ? Icons.currency_rupee_rounded
                                                : Icons.payments_outlined,
                                            color: isIncome
                                                ? AppColors.income
                                                : AppColors.expense,
                                          ),
                                          filled: true,
                                          fillColor:
                                              (isIncome
                                                      ? AppColors.income
                                                      : AppColors.expense)
                                                  .withValues(alpha: 0.06),
                                        ),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        validator: Validators.amount,
                                        autofocus: _existing == null,
                                      ),
                                      const SizedBox(height: 10),
                                      DropdownButtonFormField<String>(
                                        // ignore: deprecated_member_use
                                        value:
                                            accounts.any(
                                              (a) => a.id == _accountId,
                                            )
                                            ? _accountId
                                            : null,
                                        isExpanded: true,
                                        decoration: _denseDecoration(
                                          label: 'Account',
                                          icon: Icons
                                              .account_balance_wallet_outlined,
                                        ),
                                        items: accounts
                                            .map(
                                              (a) => DropdownMenuItem(
                                                value: a.id,
                                                child: Text(
                                                  a.accountName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(() {
                                          _accountId = v;
                                          if (_transferAccountId == v) {
                                            _transferAccountId = null;
                                          }
                                        }),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_type != TransactionType.transfer)
                                        DropdownButtonFormField<String>(
                                          // ignore: deprecated_member_use
                                          value:
                                              filteredCats.any(
                                                (c) => c.id == _categoryId,
                                              )
                                              ? _categoryId
                                              : null,
                                          isExpanded: true,
                                          decoration: _denseDecoration(
                                            label: 'Category',
                                            icon: Icons.category_outlined,
                                          ),
                                          items: filteredCats
                                              .map(
                                                (c) => DropdownMenuItem(
                                                  value: c.id,
                                                  child: Text(
                                                    c.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (v) =>
                                              setState(() => _categoryId = v),
                                        ),
                                      const SizedBox(height: 10),
                                      if (_type == TransactionType.transfer)
                                        DropdownButtonFormField<String>(
                                          initialValue:
                                              _transferAccountId !=
                                                      _accountId &&
                                                  accounts.any(
                                                    (a) =>
                                                        a.id ==
                                                        _transferAccountId,
                                                  )
                                              ? _transferAccountId
                                              : null,
                                          decoration: _denseDecoration(
                                            label: 'To account',
                                            icon: Icons.swap_horiz,
                                          ),
                                          items: accounts
                                              .where((a) => a.id != _accountId)
                                              .map(
                                                (a) => DropdownMenuItem(
                                                  value: a.id,
                                                  child: Text(a.accountName),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (value) => setState(
                                            () => _transferAccountId = value,
                                          ),
                                        ),
                                      TextFormField(
                                        controller: _merchant,
                                        decoration: _denseDecoration(
                                          label: 'Merchant / source',
                                          icon: Icons.storefront_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: _pickDateTime,
                                        borderRadius: BorderRadius.circular(14),
                                        child: InputDecorator(
                                          decoration: _denseDecoration(
                                            label: 'Date & time',
                                            icon: Icons.calendar_today_outlined,
                                            suffix: const Icon(
                                              Icons.edit_calendar_outlined,
                                              size: 18,
                                            ),
                                          ),
                                          child: Text(
                                            DateFormat.MMMd().add_jm().format(
                                              _date,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      ExpansionTile(
                                        title: const AppText('More details'),
                                        children: [
                                          const Text(
                                            'Repeat saves a template date. It does not post automatically.',
                                          ),
                                          DropdownButtonFormField<
                                            RecurrenceInterval
                                          >(
                                            // ignore: deprecated_member_use
                                            value: _recurrence,
                                            isExpanded: true,
                                            decoration: _denseDecoration(
                                              label: 'Repeat template (manual)',
                                              icon: Icons.repeat,
                                            ),
                                            items: RecurrenceInterval.values
                                                .map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Text(
                                                      e.name[0].toUpperCase() +
                                                          e.name.substring(1),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) => setState(
                                              () => _recurrence =
                                                  v ?? RecurrenceInterval.none,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: _location,
                                            decoration: _denseDecoration(
                                              label: 'Location',
                                              icon: Icons.place_outlined,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextFormField(
                                            controller: _notes,
                                            maxLines: 2,
                                            minLines: 2,
                                            decoration: _denseDecoration(
                                              label: 'Notes',
                                              icon: Icons.notes_outlined,
                                            ),
                                          ),
                                          TextFormField(
                                            controller: _tags,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Tags (comma separated)',
                                            ),
                                          ),
                                          if (_receiptUrl != null)
                                            ListTile(
                                              leading: const Icon(
                                                Icons.receipt_long,
                                              ),
                                              title: const Text(
                                                'Receipt attached',
                                              ),
                                              trailing: IconButton(
                                                onPressed: () => setState(
                                                  () => _receiptUrl = null,
                                                ),
                                                icon: const Icon(Icons.close),
                                              ),
                                              onTap: () => showDialog<void>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  content: Image.network(
                                                    _receiptUrl!,
                                                    errorBuilder:
                                                        (
                                                          _,
                                                          error,
                                                          stack,
                                                        ) => const Text(
                                                          'Receipt unavailable',
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          TextButton.icon(
                                            onPressed: _uploading
                                                ? null
                                                : _attachReceipt,
                                            icon: const Icon(Icons.attach_file),
                                            label: Text(
                                              _uploading
                                                  ? 'Uploading...'
                                                  : 'Attach receipt',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                12,
                                22,
                                16,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                border: Border(
                                  top: BorderSide(
                                    color: Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _loading ? null : _close,
                                      child: const AppText('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: FilledButton.icon(
                                      onPressed:
                                          (_loading ||
                                              _bootstrapping ||
                                              accounts.isEmpty ||
                                              (_type !=
                                                      TransactionType
                                                          .transfer &&
                                                  filteredCats.isEmpty) ||
                                              _uploading)
                                          ? null
                                          : _save,
                                      icon: _loading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              isIncome
                                                  ? Icons.add_rounded
                                                  : Icons.check_rounded,
                                            ),
                                      label: Text(
                                        _existing == null ? 'Save' : 'Update',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.isIncome,
    required this.showDelete,
    required this.onClose,
    required this.onDelete,
  });

  final String title;
  final bool isIncome;
  final bool showDelete;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isIncome
              ? [AppColors.income.withValues(alpha: 0.12), Colors.transparent]
              : [AppColors.azure.withValues(alpha: 0.12), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isIncome ? AppColors.income : AppColors.azure).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: isIncome ? AppColors.income : AppColors.azure,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (showDelete)
            IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
