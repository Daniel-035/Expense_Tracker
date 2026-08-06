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

class _TransactionFormScreenState
    extends ConsumerState<TransactionFormScreen> {
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

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _bootstrap();
      _loadExisting();
    });
  }

  Future<void> _bootstrap() async {
    try {
      await ref.read(userBootstrapProvider).ensureDefaults();
      ref.invalidate(accountsProvider);
      ref.invalidate(categoriesProvider);
    } catch (_) {
      // Still allow the form; save will show a clear error.
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  void _loadExisting() {
    if (widget.transactionId == null || widget.transactionId == 'new') return;
    final txs = ref.read(transactionsProvider).asData?.value ?? [];
    final found = txs.where((t) => t.id == widget.transactionId).firstOrNull;
    if (found == null) return;
    setState(() {
      _existing = found;
      _type = found.transactionType == TransactionType.transfer
          ? TransactionType.expense
          : found.transactionType;
      _amount.text = found.amount.toString();
      _merchant.text = found.merchant ?? '';
      _notes.text = found.notes ?? '';
      _location.text = found.location ?? '';
      _accountId = found.accountId;
      _categoryId = found.categoryId;
      _date = found.createdAt;
      _recurrence = found.recurrence;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _notes.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null || _categoryId == null) {
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
      await ref.read(userBootstrapProvider).ensureDefaults();
      final tx = MoneyTransaction(
        id: _existing?.id ?? const Uuid().v4(),
        accountId: _accountId!,
        categoryId: _categoryId!,
        amount: double.parse(_amount.text.trim()),
        transactionType: _type,
        merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        location: _location.text.trim().isEmpty ? null : _location.text.trim(),
        recurrence: _recurrence,
        nextOccurrence: _recurrence == RecurrenceInterval.none
            ? null
            : _nextFrom(_date, _recurrence),
        createdAt: _date,
      );
      final repo = ref.read(transactionsRepositoryProvider);
      if (_existing == null) {
        await repo.create(tx);
      } else {
        await repo.update(tx);
      }
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/transactions');
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _nextFrom(DateTime from, RecurrenceInterval interval) {
    switch (interval) {
      case RecurrenceInterval.daily:
        return from.add(const Duration(days: 1));
      case RecurrenceInterval.weekly:
        return from.add(const Duration(days: 7));
      case RecurrenceInterval.monthly:
        return DateTime(from.year, from.month + 1, from.day);
      case RecurrenceInterval.yearly:
        return DateTime(from.year + 1, from.month, from.day);
      case RecurrenceInterval.none:
        return from;
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
      labelText: label,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIcon: Icon(icon, size: 20),
      suffixIcon: suffix,
    );
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
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

    if (_accountId == null && accounts.isNotEmpty) {
      _accountId = accounts.first.id;
    } else if (_accountId != null &&
        accounts.isNotEmpty &&
        !accounts.any((a) => a.id == _accountId)) {
      _accountId = accounts.first.id;
    }
    if (_categoryId == null && filteredCats.isNotEmpty) {
      _categoryId = filteredCats.first.id;
    } else if (_categoryId != null &&
        filteredCats.isNotEmpty &&
        !filteredCats.any((c) => c.id == _categoryId)) {
      _categoryId = filteredCats.first.id;
    }

    final isIncome = _type == TransactionType.income;
    final title = _existing == null
        ? (isIncome ? 'Add income' : 'Add expense')
        : 'Edit transaction';
    final size = MediaQuery.sizeOf(context);
    final maxCardWidth = size.width >= 900
        ? 640.0
        : size.width >= 600
            ? size.width * 0.72
            : size.width * 0.94;

    return Scaffold(
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
                            onDelete: () async {
                              await ref
                                  .read(transactionsRepositoryProvider)
                                  .delete(_existing!.id);
                              if (context.mounted) _close();
                            },
                          ),
                          if (_bootstrapping)
                            const LinearProgressIndicator(minHeight: 2),
                          Flexible(
                            child: Form(
                              key: _formKey,
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.fromLTRB(22, 8, 22, 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (accounts.isEmpty ||
                                        filteredCats.isEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Text(
                                          accounts.isEmpty
                                              ? 'No accounts yet — creating defaults…'
                                              : 'No categories for this type — creating defaults…',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
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
                                          label: Text('Expense'),
                                          icon:
                                              Icon(Icons.north_east_rounded),
                                        ),
                                        ButtonSegment(
                                          value: TransactionType.income,
                                          label: Text('Income'),
                                          icon:
                                              Icon(Icons.south_west_rounded),
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
                                        labelText: 'Amount',
                                        hintText: '0.00',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.currency_rupee_rounded,
                                          color: isIncome
                                              ? AppColors.income
                                              : AppColors.expense,
                                        ),
                                        filled: true,
                                        fillColor: (isIncome
                                                ? AppColors.income
                                                : AppColors.expense)
                                            .withValues(alpha: 0.06),
                                      ),
                                      keyboardType: const TextInputType
                                          .numberWithOptions(decimal: true),
                                      validator: Validators.amount,
                                      autofocus: _existing == null,
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      // ignore: deprecated_member_use
                                      value: accounts.any(
                                              (a) => a.id == _accountId)
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
                                      onChanged: (v) =>
                                          setState(() => _accountId = v),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      // ignore: deprecated_member_use
                                      value: filteredCats.any(
                                              (c) => c.id == _categoryId)
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
                                          icon:
                                              Icons.calendar_today_outlined,
                                          suffix: const Icon(
                                            Icons.edit_calendar_outlined,
                                            size: 18,
                                          ),
                                        ),
                                        child: Text(
                                          DateFormat.MMMd()
                                              .add_jm()
                                              .format(_date),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<
                                        RecurrenceInterval>(
                                      // ignore: deprecated_member_use
                                      value: _recurrence,
                                      isExpanded: true,
                                      decoration: _denseDecoration(
                                        label: 'Repeat',
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
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets.fromLTRB(22, 12, 22, 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              border: Border(
                                top: BorderSide(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _loading ? null : _close,
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton.icon(
                                    onPressed: (_loading ||
                                            _bootstrapping ||
                                            accounts.isEmpty ||
                                            filteredCats.isEmpty)
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
              ? [
                  AppColors.income.withValues(alpha: 0.12),
                  Colors.transparent,
                ]
              : [
                  AppColors.azure.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isIncome ? AppColors.income : AppColors.azure)
                  .withValues(alpha: 0.12),
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
