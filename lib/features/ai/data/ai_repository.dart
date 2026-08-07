import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as gai;

import '../../../core/errors/app_exception.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/rate_limiter.dart';
import '../../../core/utils/report_export.dart';
import '../../accounts/data/accounts_repository.dart';
import '../../budgets/data/budgets_repository.dart';
import '../../budgets/domain/budget.dart';
import '../../settings/data/settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/domain/money_transaction.dart';
import '../../categories/data/categories_repository.dart';

class AiReply {
  const AiReply({required this.text, this.report});

  final String text;
  final ReportBundle? report;
}

const _softwareKnowledge = '''
You are LedgerOne's in-app AI assistant with FULL product knowledge and the user's live finance data.

PRODUCT: LedgerOne — personal expense tracker (Flutter + Firebase) for Android, iOS, and Web.
Live site: https://expense-tracker-70365.web.app

FEATURES & HOW TO USE:
- Auth: email/password, Google sign-in, forgot password, logout, delete account.
- Dashboard: balance, income/expense, recent activity, AI Chat shortcut.
- Transactions/Activity: add income & expense (+ button), search, filter, edit/delete.
- Accounts: Cash and other wallets; transfers between accounts.
- Categories: income/expense categories (defaults seeded).
- Budgets: weekly/monthly limits; progress updates LIVE from expenses.
- Bills, Goals, Analytics/Insights, Calendar.
- Profile: name/phone, upload photo (Firebase Storage), language, currency.
- Settings: theme (system/light/dark), language English/Hindi, currency, biometric/PIN, export data, logout.
- Download/Share: Activity CSV and PDF from Transactions, Settings, and Chat.
- AI Chat: type any question; request PDF/CSV reports; share reports.

NAVIGATION:
- Mobile bottom nav: Home, Activity, Budgets, Insights, Chat, Profile.
- Desktop sidebar includes Accounts, Categories, Bills, Goals, Analytics, Calendar, Chat, Settings.

RULES:
- Answer EVERY question about LedgerOne features, navigation, and the user's money data.
- Prefer the user's preferred language (en/hi).
- Be concise, practical, and accurate. If data is missing, say so and guide the user.
- When the user asks for a report, export, PDF, CSV, statement, or shareable summary, CALL the export_activity_report tool.
- You cannot literally transfer money or mutate data; explain how the user can do it in the app.
- Currency: format with the user's currency (INR → ₹ when helpful).
''';

/// Optional unrestricted key from Google AI Studio:
/// `flutter build web --dart-define=GEMINI_API_KEY=...`
const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
const _aiModelName = 'gemini-3.6-flash';

class AiRepository {
  AiRepository(this._ref);

  final Ref _ref;
  GenerativeModel? _firebaseModel;
  gai.GenerativeModel? _directModel;
  ChatSession? _firebaseChat;
  gai.ChatSession? _directChat;
  ReportBundle? _lastReport;

  bool get _useDirectGemini => _geminiApiKey.isNotEmpty;

  GenerativeModel _ensureFirebaseModel() {
    _firebaseModel ??=
        FirebaseAI.googleAI(
          appCheck: FirebaseAppCheck.instance,
          useLimitedUseAppCheckTokens: true,
        ).generativeModel(
          model: _aiModelName,
          systemInstruction: Content.system(_softwareKnowledge),
          tools: [
            Tool.functionDeclarations([
              FunctionDeclaration(
                'export_activity_report',
                'Generate a downloadable LedgerOne activity/finance report for the user as CSV and/or PDF.',
                parameters: {
                  'format': Schema.enumString(
                    enumValues: ['csv', 'pdf', 'both'],
                    description: 'File format to prepare',
                  ),
                  'title': Schema.string(
                    description: 'Report title shown in PDF and share sheet',
                  ),
                  'summary': Schema.string(
                    description:
                        'Short narrative summary included in the PDF report',
                  ),
                },
              ),
            ]),
          ],
        );
    return _firebaseModel!;
  }

  gai.GenerativeModel _ensureDirectModel() {
    _directModel ??= gai.GenerativeModel(
      model: _aiModelName,
      apiKey: _geminiApiKey,
      systemInstruction: gai.Content.system(_softwareKnowledge),
      tools: [
        gai.Tool(
          functionDeclarations: [
            gai.FunctionDeclaration(
              'export_activity_report',
              'Generate a downloadable LedgerOne activity/finance report for the user as CSV and/or PDF.',
              gai.Schema.object(
                properties: {
                  'format': gai.Schema.enumString(
                    enumValues: const ['csv', 'pdf', 'both'],
                    description: 'File format to prepare',
                  ),
                  'title': gai.Schema.string(
                    description: 'Report title shown in PDF and share sheet',
                  ),
                  'summary': gai.Schema.string(
                    description:
                        'Short narrative summary included in the PDF report',
                  ),
                },
              ),
            ),
          ],
        ),
      ],
    );
    return _directModel!;
  }

  String _buildSnapshot() {
    final currency =
        _ref.read(settingsProvider).asData?.value.currency ?? 'INR';
    final lang = _ref.read(settingsProvider).asData?.value.language ?? 'en';
    final txs =
        _ref.read(transactionsProvider).asData?.value ??
        const <MoneyTransaction>[];
    final budgets =
        _ref.read(budgetsProvider).asData?.value ?? const <Budget>[];
    final accounts = _ref.read(accountsProvider).asData?.value ?? const [];
    final categories = _ref.read(categoriesProvider).asData?.value ?? const [];

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    var income = 0.0;
    var expense = 0.0;
    for (final t in txs) {
      if (t.createdAt.isBefore(monthStart)) continue;
      if (t.transactionType == TransactionType.income) income += t.amount;
      if (t.transactionType == TransactionType.expense) expense += t.amount;
    }
    final balance = accounts.fold<double>(0, (s, a) => s + a.balance);
    final liveBudgets = budgets.map((b) => b.withLiveSpent(txs)).toList();

    final budgetLines = liveBudgets.isEmpty
        ? 'No budgets set.'
        : liveBudgets
              .map(
                (b) =>
                    '- limit ${b.amount} spent ${b.spent.toStringAsFixed(0)} '
                    '(${b.period.name}${b.categoryIds.isEmpty ? ', overall' : ', ${b.categoryIds.length} categories'})',
              )
              .join('\n');

    return '''
LIVE USER DATA SNAPSHOT:
- Preferred language: $lang
- Currency: $currency
- Accounts (${accounts.length}): ${accounts.map((a) => '${a.accountName}=${a.balance}').join(', ')}
- Categories: ${categories.length}
- Total balance: $balance
- This month income: $income
- This month expense: $expense
- Budgets:
$budgetLines
- Recent transactions (up to 15):
${txs.take(15).map((t) => '${t.createdAt.toIso8601String().substring(0, 10)} ${t.transactionType.name} ${t.amount} ${t.merchant ?? ""}').join('\n')}
''';
  }

  ReportFormat _parseFormat(Object? raw) {
    switch ('$raw'.toLowerCase()) {
      case 'csv':
        return ReportFormat.csv;
      case 'pdf':
        return ReportFormat.pdf;
      default:
        return ReportFormat.both;
    }
  }

  Future<Map<String, Object?>> _runExportTool(Map<String, Object?> args) async {
    final format = _parseFormat(args['format']);
    final title = (args['title'] as String?)?.trim().isNotEmpty == true
        ? args['title'] as String
        : 'LedgerOne Activity Report';
    final summary = args['summary'] as String?;

    final currency =
        _ref.read(settingsProvider).asData?.value.currency ?? 'INR';
    final txs =
        _ref.read(transactionsProvider).asData?.value ??
        const <MoneyTransaction>[];
    final budgets =
        _ref.read(budgetsProvider).asData?.value ?? const <Budget>[];
    final accounts = _ref.read(accountsProvider).asData?.value ?? const [];
    final categories = _ref.read(categoriesProvider).asData?.value ?? const [];

    final bundle = await buildActivityReport(
      transactions: txs,
      categories: categories,
      accounts: accounts,
      budgets: budgets,
      currency: currency,
      title: title,
      narrative: summary,
      format: format,
    );

    _lastReport = bundle;

    return {
      'status': 'ready',
      'title': bundle.title,
      'hasCsv': bundle.hasCsv,
      'hasPdf': bundle.hasPdf,
      'transactionCount': txs.length,
      'message':
          'Report prepared. The app will show Download PDF / CSV and Share buttons.',
    };
  }

  String get _userPayload {
    final snapshot = _buildSnapshot();
    return '$snapshot\n\nUser message:\n';
  }

  Future<AiReply> _askFirebase(String prompt) async {
    final model = _ensureFirebaseModel();
    _firebaseChat ??= model.startChat();
    var response = await _firebaseChat!.sendMessage(
      Content.text(
        '$_userPayload$prompt\n\n'
        'If they want a report/PDF/CSV/export/share, call export_activity_report.',
      ),
    );

    for (var i = 0; i < 3; i++) {
      final calls = response.functionCalls.toList();
      if (calls.isEmpty) break;
      final results = <FunctionResponse>[];
      for (final call in calls) {
        if (call.name == 'export_activity_report') {
          final out = await _runExportTool(call.args);
          results.add(FunctionResponse(call.name, out));
        } else {
          results.add(
            FunctionResponse(call.name, {
              'error': 'Unknown function ${call.name}',
            }),
          );
        }
      }
      response = await _firebaseChat!.sendMessage(
        Content.functionResponses(results),
      );
    }

    final text = response.text?.trim();
    if ((text == null || text.isEmpty) && _lastReport == null) {
      throw DataException('Empty AI response');
    }
    return AiReply(
      text: text?.isNotEmpty == true
          ? text!
          : 'Your report is ready. Use Download or Share below.',
      report: _lastReport,
    );
  }

  Future<AiReply> _askDirect(String prompt) async {
    final model = _ensureDirectModel();
    _directChat ??= model.startChat();
    var response = await _directChat!.sendMessage(
      gai.Content.text(
        '$_userPayload$prompt\n\n'
        'If they want a report/PDF/CSV/export/share, call export_activity_report.',
      ),
    );

    for (var i = 0; i < 3; i++) {
      final calls = response.functionCalls.toList();
      if (calls.isEmpty) break;
      final results = <gai.FunctionResponse>[];
      for (final call in calls) {
        if (call.name == 'export_activity_report') {
          final out = await _runExportTool(call.args);
          results.add(gai.FunctionResponse(call.name, out));
        } else {
          results.add(
            gai.FunctionResponse(call.name, {
              'error': 'Unknown function ${call.name}',
            }),
          );
        }
      }
      response = await _directChat!.sendMessage(
        gai.Content.functionResponses(results),
      );
    }

    final text = response.text?.trim();
    if ((text == null || text.isEmpty) && _lastReport == null) {
      throw DataException('Empty AI response');
    }
    return AiReply(
      text: text?.isNotEmpty == true
          ? text!
          : 'Your report is ready. Use Download or Share below.',
      report: _lastReport,
    );
  }

  Future<AiReply> ask(String prompt) async {
    final backend = _ref.read(appBackendProvider);
    if (backend.isDemo) {
      return _demoReply(prompt);
    }

    RateLimiter.instance.ensureAllowed('ai_ask', max: 12, windowSeconds: 60);
    _lastReport = null;

    try {
      if (_useDirectGemini) {
        return await _askDirect(prompt);
      }
      return await _askFirebase(prompt);
    } on RateLimitException {
      rethrow;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('prepayment credits') ||
          msg.contains('RESOURCE_EXHAUSTED') ||
          msg.contains('quota') ||
          msg.contains('429')) {
        throw DataException(
          'Cloud AI credits are depleted. Add Gemini API credits in Google AI '
          'Studio, then try again.',
        );
      }
      if (msg.contains('App Check') || msg.contains('app-check')) {
        throw DataException(
          kIsWeb
              ? 'AI verification failed. Refresh the page and try again. If it '
                    'continues, verify the web reCAPTCHA Enterprise registration in '
                    'Firebase App Check.'
              : 'AI blocked by App Check. Register a debug token in Firebase '
                    'Console → App Check → your app → Manage debug tokens.',
        );
      }
      if (msg.contains('blocked') ||
          msg.contains('generativelanguage.googleapis.com')) {
        throw DataException(
          'Gemini API access is blocked for this project. Verify Firebase AI '
          'Logic onboarding and API-key restrictions, then try again.',
        );
      }
      if (msg.contains('API') ||
          msg.contains('permission') ||
          msg.contains('not enabled') ||
          msg.contains('404') ||
          msg.contains('FAILED_PRECONDITION')) {
        throw DataException(
          'AI unavailable. In Firebase Console open Build → AI Logic, '
          'enable Gemini Developer API (free tier), then try again.',
        );
      }
      throw DataException('AI request failed: $e');
    }
  }

  Future<AiReply> _demoReply(String prompt) async {
    RateLimiter.instance.ensureAllowed('ai_ask', max: 20, windowSeconds: 60);
    final lower = prompt.toLowerCase();
    ReportBundle? report;
    if (lower.contains('pdf') ||
        lower.contains('csv') ||
        lower.contains('report') ||
        lower.contains('export')) {
      final currency =
          _ref.read(settingsProvider).asData?.value.currency ?? 'INR';
      report = await buildActivityReport(
        transactions: _ref.read(transactionsProvider).asData?.value ?? const [],
        categories: _ref.read(categoriesProvider).asData?.value ?? const [],
        accounts: _ref.read(accountsProvider).asData?.value ?? const [],
        budgets: _ref.read(budgetsProvider).asData?.value ?? const [],
        currency: currency,
        title: 'LedgerOne Demo Report',
        narrative: 'Demo-mode report generated from local data.',
        format: ReportFormat.both,
      );
    }
    return AiReply(
      text:
          'Demo chat reply for "$prompt".\n\nI know LedgerOne features (dashboard, activity, budgets, goals, Hindi/English, exports). '
          '${report != null ? "A sample report is ready to download/share." : "Ask for a PDF or CSV report anytime."}',
      report: report,
    );
  }

  void resetChat() {
    _firebaseChat = null;
    _directChat = null;
    _lastReport = null;
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref);
});
