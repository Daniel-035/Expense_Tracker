import '../utils/money.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/default_categories.dart';
import '../../features/accounts/domain/account.dart';
import '../../features/bills/domain/bill.dart';
import '../../features/budgets/domain/budget.dart';
import '../../features/categories/domain/category.dart';
import '../../features/goals/domain/savings_goal.dart';
import '../../features/profile/domain/user_profile.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../features/transactions/domain/money_transaction.dart';
import '../../features/transactions/domain/transaction_ledger.dart';

/// In-memory + SharedPreferences store used for demo / offline fallback.
class DemoStore {
  DemoStore._();
  static final DemoStore instance = DemoStore._();

  final _uuid = const Uuid();
  final _userController = StreamController<UserProfile?>.broadcast();
  final _accountsController = StreamController<List<Account>>.broadcast();
  final _categoriesController = StreamController<List<Category>>.broadcast();
  final _txController = StreamController<List<MoneyTransaction>>.broadcast();
  final _budgetsController = StreamController<List<Budget>>.broadcast();
  final _billsController = StreamController<List<Bill>>.broadcast();
  final _goalsController = StreamController<List<SavingsGoal>>.broadcast();
  final _settingsController = StreamController<AppSettings>.broadcast();

  UserProfile? user;
  UserProfile? persistedUser;
  bool signedIn = false;
  AppSettings settings = const AppSettings();
  final List<Account> accounts = [];
  final List<Category> categories = [];
  final List<MoneyTransaction> transactions = [];
  final List<Budget> budgets = [];
  final List<Bill> bills = [];
  final List<SavingsGoal> goals = [];
  final Map<String, List<GoalDeposit>> goalDeposits = {};

  String? demoPassword;

  UserProfile? get sessionUser => signedIn ? (user ?? persistedUser) : null;

  Stream<UserProfile?> get userStream => _userController.stream;
  Stream<List<Account>> get accountsStream => _accountsController.stream;
  Stream<List<Category>> get categoriesStream => _categoriesController.stream;
  Stream<List<MoneyTransaction>> get transactionsStream => _txController.stream;
  Stream<List<Budget>> get budgetsStream => _budgetsController.stream;
  Stream<List<Bill>> get billsStream => _billsController.stream;
  Stream<List<SavingsGoal>> get goalsStream => _goalsController.stream;
  Stream<AppSettings> get settingsStream => _settingsController.stream;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ledgerone_demo_v1');
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      demoPassword = map['demoPassword'] as String?;
      if (map['user'] != null) {
        final u = map['user'] as Map<String, dynamic>;
        persistedUser = UserProfile.fromMap(u['id'] as String, u);
        user = persistedUser;
        signedIn = map['signedIn'] as bool? ?? true;
      }
      settings = AppSettings.fromMap(map['settings'] as Map<String, dynamic>?);
      accounts
        ..clear()
        ..addAll(
          ((map['accounts'] as List?) ?? []).map(
            (e) => Account.fromMap(
              e['id'] as String,
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      categories
        ..clear()
        ..addAll(
          ((map['categories'] as List?) ?? []).map(
            (e) => Category.fromMap(
              e['id'] as String,
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      transactions
        ..clear()
        ..addAll(
          ((map['transactions'] as List?) ?? []).map(
            (e) => MoneyTransaction.fromMap(
              e['id'] as String,
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      budgets
        ..clear()
        ..addAll(
          ((map['budgets'] as List?) ?? []).map(
            (e) => Budget.fromMap(
              e['id'] as String,
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      bills
        ..clear()
        ..addAll(
          ((map['bills'] as List?) ?? []).map(
            (e) => Bill.fromMap(
              e['id'] as String,
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      goals
        ..clear()
        ..addAll(
          ((map['goals'] as List?) ?? []).map(
            (e) => SavingsGoal.fromMap(
              e['id'] as String,
              Map<String, dynamic>.from(e as Map),
            ),
          ),
        );
      _emitAll();
    } catch (e) {
      debugPrint('DemoStore load failed: $e');
    }
  }

  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'demoPassword': demoPassword,
      'signedIn': signedIn,
      'user': persistedUser == null
          ? null
          : {...persistedUser!.toMap(), 'id': persistedUser!.id},
      'settings': settings.toMap(),
      'accounts': accounts.map((e) => {...e.toMap(), 'id': e.id}).toList(),
      'categories': categories.map((e) => {...e.toMap(), 'id': e.id}).toList(),
      'transactions': transactions
          .map((e) => {...e.toMap(), 'id': e.id})
          .toList(),
      'budgets': budgets.map((e) => {...e.toMap(), 'id': e.id}).toList(),
      'bills': bills.map((e) => {...e.toMap(), 'id': e.id}).toList(),
      'goals': goals.map((e) => {...e.toMap(), 'id': e.id}).toList(),
    };
    await prefs.setString('ledgerone_demo_v1', jsonEncode(payload));
  }

  void _emitAll() {
    _userController.add(sessionUser);
    _accountsController.add(List.unmodifiable(accounts));
    _categoriesController.add(List.unmodifiable(categories));
    _txController.add(List.unmodifiable(transactions));
    _budgetsController.add(List.unmodifiable(budgets));
    _billsController.add(List.unmodifiable(bills));
    _goalsController.add(List.unmodifiable(goals));
    _settingsController.add(settings);
  }

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final id = _uuid.v4();
    user = UserProfile(
      id: id,
      email: email.trim().toLowerCase(),
      name: name.trim(),
      createdAt: DateTime.now(),
    );
    persistedUser = user;
    demoPassword = password;
    categories.clear();
    for (final def in kDefaultCategories) {
      categories.add(
        Category(
          id: _uuid.v4(),
          name: def.name,
          type: def.type == 'income'
              ? CategoryType.income
              : CategoryType.expense,
          color: def.color,
          icon: def.icon,
          isSystem: true,
        ),
      );
    }
    accounts
      ..clear()
      ..add(
        Account(
          id: _uuid.v4(),
          accountName: 'Cash',
          accountType: AccountType.cash,
          balance: 0,
        ),
      );
    settings = const AppSettings();
    transactions.clear();
    budgets.clear();
    bills.clear();
    goals.clear();
    signedIn = true;
    await persist();
    _emitAll();
    return user!;
  }

  Future<UserProfile> login(String email, String password) async {
    if (persistedUser == null ||
        persistedUser!.email != email.trim().toLowerCase() ||
        demoPassword != password) {
      throw Exception('Invalid email or password');
    }
    user = persistedUser;
    signedIn = true;
    _emitAll();
    return user!;
  }

  Future<void> logout() async {
    signedIn = false;
    await persist();
    _userController.add(null);
  }

  Future<void> deleteAccount() async {
    user = null;
    persistedUser = null;
    signedIn = false;
    demoPassword = null;
    accounts.clear();
    categories.clear();
    transactions.clear();
    budgets.clear();
    bills.clear();
    goals.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ledgerone_demo_v1');
    _emitAll();
  }

  Future<void> updateProfile(UserProfile profile) async {
    user = profile;
    persistedUser = profile;
    await persist();
    _userController.add(sessionUser);
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await persist();
    _settingsController.add(settings);
  }

  // ---- Accounts ----
  Future<Account> upsertAccount(Account account) async {
    final idx = accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) {
      accounts[idx] = account;
    } else {
      accounts.add(account);
    }
    await persist();
    _accountsController.add(List.unmodifiable(accounts));
    return account;
  }

  Future<void> deleteAccountById(String id) async {
    accounts.removeWhere((a) => a.id == id);
    await persist();
    _accountsController.add(List.unmodifiable(accounts));
  }

  Future<void> transfer({
    required String fromId,
    required String toId,
    required double amount,
    String? notes,
  }) async {
    accounts.firstWhere((a) => a.id == fromId);
    accounts.firstWhere((a) => a.id == toId);
    final transferCategoryId = categories.isEmpty
        ? ''
        : categories
              .firstWhere(
                (c) => c.name == 'Miscellaneous',
                orElse: () => categories.first,
              )
              .id;
    await upsertTransaction(
      MoneyTransaction(
        id: _uuid.v4(),
        accountId: fromId,
        categoryId: transferCategoryId,
        amount: amount,
        transactionType: TransactionType.transfer,
        transferAccountId: toId,
        notes: notes ?? 'Transfer',
        createdAt: DateTime.now(),
      ),
    );
  }

  // ---- Categories ----
  Future<Category> upsertCategory(Category category) async {
    final idx = categories.indexWhere((c) => c.id == category.id);
    if (idx >= 0) {
      categories[idx] = category;
    } else {
      categories.add(category);
    }
    await persist();
    _categoriesController.add(List.unmodifiable(categories));
    return category;
  }

  Future<void> deleteCategory(String id) async {
    categories.removeWhere((c) => c.id == id && !c.isSystem);
    await persist();
    _categoriesController.add(List.unmodifiable(categories));
  }

  // ---- Transactions ----
  Future<MoneyTransaction> upsertTransaction(MoneyTransaction tx) async {
    Money.minor(tx.amount, positive: true);
    final affected = transactionBalanceDeltas(tx).keys;
    if (affected.any((id) => accounts.every((a) => a.id != id))) {
      throw StateError('Account not found.');
    }
    final existingIdx = transactions.indexWhere((t) => t.id == tx.id);
    if (existingIdx >= 0 &&
        transactionBalanceDeltas(
          transactions[existingIdx],
        ).keys.any((id) => accounts.every((a) => a.id != id))) {
      throw StateError('Original account not found.');
    }
    MoneyTransaction? previous;
    if (existingIdx >= 0) {
      previous = transactions[existingIdx];
      transactions[existingIdx] = tx;
    } else {
      transactions.insert(0, tx);
    }

    // Revert previous balance impact
    if (previous != null) {
      _applyBalance(previous, reverse: true);
    }
    _applyBalance(tx, reverse: false);
    _recalcBudgets();
    await persist();
    _txController.add(List.unmodifiable(transactions));
    _accountsController.add(List.unmodifiable(accounts));
    _budgetsController.add(List.unmodifiable(budgets));
    return tx;
  }

  void _applyBalance(MoneyTransaction tx, {required bool reverse}) {
    final deltas = transactionBalanceDeltas(tx, reverse: reverse);
    final missingAccount = deltas.keys
        .where((id) => accounts.every((account) => account.id != id))
        .firstOrNull;
    if (missingAccount != null) {
      throw StateError('Account not found: $missingAccount');
    }
    for (final entry in deltas.entries) {
      final index = accounts.indexWhere((a) => a.id == entry.key);
      final account = accounts[index];
      accounts[index] = account.copyWith(
        balance: Money.add(account.balance, entry.value),
      );
    }
  }

  Future<void> deleteTransaction(String id) async {
    final idx = transactions.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final tx = transactions[idx];
    _applyBalance(tx, reverse: true);
    transactions.removeAt(idx);
    _recalcBudgets();
    await persist();
    _txController.add(List.unmodifiable(transactions));
    _accountsController.add(List.unmodifiable(accounts));
    _budgetsController.add(List.unmodifiable(budgets));
  }

  void _recalcBudgets() {
    for (var i = 0; i < budgets.length; i++) {
      budgets[i] = budgets[i].withLiveSpent(transactions);
    }
  }

  // ---- Budgets / Bills / Goals ----
  Future<Budget> upsertBudget(Budget budget) async {
    final idx = budgets.indexWhere((b) => b.id == budget.id);
    if (idx >= 0) {
      budgets[idx] = budget;
    } else {
      budgets.add(budget);
    }
    _recalcBudgets();
    await persist();
    _budgetsController.add(List.unmodifiable(budgets));
    return budgets.firstWhere((b) => b.id == budget.id);
  }

  Future<void> deleteBudget(String id) async {
    budgets.removeWhere((b) => b.id == id);
    await persist();
    _budgetsController.add(List.unmodifiable(budgets));
  }

  Future<Bill> upsertBill(Bill bill) async {
    final idx = bills.indexWhere((b) => b.id == bill.id);
    if (idx >= 0) {
      bills[idx] = bill;
    } else {
      bills.add(bill);
    }
    await persist();
    _billsController.add(List.unmodifiable(bills));
    return bill;
  }

  Future<void> deleteBill(String id) async {
    bills.removeWhere((b) => b.id == id);
    await persist();
    _billsController.add(List.unmodifiable(bills));
  }

  Future<SavingsGoal> upsertGoal(SavingsGoal goal) async {
    final idx = goals.indexWhere((g) => g.id == goal.id);
    if (idx >= 0) {
      goals[idx] = goal;
    } else {
      goals.add(goal);
      goalDeposits[goal.id] = [];
    }
    await persist();
    _goalsController.add(List.unmodifiable(goals));
    return goal;
  }

  Future<void> deleteGoal(String id) async {
    goals.removeWhere((g) => g.id == id);
    goalDeposits.remove(id);
    await persist();
    _goalsController.add(List.unmodifiable(goals));
  }

  Future<SavingsGoal> depositToGoal({
    required String goalId,
    required double amount,
    String? note,
  }) async {
    final idx = goals.indexWhere((g) => g.id == goalId);
    if (idx < 0) throw Exception('Goal not found');
    final goal = goals[idx];
    final updated = SavingsGoal(
      id: goal.id,
      goalName: goal.goalName,
      targetAmount: goal.targetAmount,
      savedAmount: Money.add(goal.savedAmount, amount),
      deadline: goal.deadline,
    );
    goals[idx] = updated;
    goalDeposits
        .putIfAbsent(goalId, () => [])
        .add(
          GoalDeposit(
            id: _uuid.v4(),
            amount: amount,
            createdAt: DateTime.now(),
            note: note,
          ),
        );
    await persist();
    _goalsController.add(List.unmodifiable(goals));
    return updated;
  }

  String newId() => _uuid.v4();
}
