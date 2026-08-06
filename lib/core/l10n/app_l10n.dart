import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/settings_repository.dart';

/// App-wide English / Hindi strings. Switch via Settings → Language.
class AppL10n {
  const AppL10n(this.languageCode);

  final String languageCode;

  bool get isHindi => languageCode == 'hi';

  static const supported = [
    Locale('en'),
    Locale('hi'),
  ];

  String get localeTag => isHindi ? 'hi' : 'en';

  String _t(String en, String hi) => isHindi ? hi : en;

  // —— Common ——
  String get appName => 'LedgerOne';
  String get save => _t('Save', 'सहेजें');
  String get cancel => _t('Cancel', 'रद्द करें');
  String get delete => _t('Delete', 'हटाएँ');
  String get loading => _t('Loading…', 'लोड हो रहा है…');
  String get error => _t('Something went wrong', 'कुछ गलत हो गया');
  String get retry => _t('Retry', 'फिर से कोशिश करें');
  String get logout => _t('Logout', 'लॉग आउट');
  String get settings => _t('Settings', 'सेटिंग्स');
  String get profile => _t('Profile', 'प्रोफ़ाइल');
  String get language => _t('Language', 'भाषा');
  String get english => _t('English', 'अंग्रेज़ी');
  String get hindi => _t('Hindi', 'हिन्दी');
  String get currency => _t('Currency', 'मुद्रा');
  String get appearance => _t('Appearance', 'दिखावट');
  String get system => _t('System', 'सिस्टम');
  String get light => _t('Light', 'लाइट');
  String get dark => _t('Dark', 'डार्क');
  String get notifications => _t('Notifications', 'सूचनाएँ');
  String get overall => _t('Overall', 'कुल');
  String get remaining => _t('Remaining', 'शेष');
  String get exceeded => _t('Budget exceeded', 'बजट पार हो गया');
  String get create => _t('Create', 'बनाएँ');
  String get download => _t('Download', 'डाउनलोड');
  String get uploadPhoto => _t('Change photo', 'फ़ोटो बदलें');

  // —— Nav ——
  String get navHome => _t('Home', 'होम');
  String get navActivity => _t('Activity', 'गतिविधि');
  String get navBudgets => _t('Budgets', 'बजट');
  String get navInsights => _t('Insights', 'इनसाइट्स');
  String get navProfile => _t('Profile', 'प्रोफ़ाइल');
  String get navDashboard => _t('Dashboard', 'डैशबोर्ड');
  String get navTransactions => _t('Transactions', 'लेन-देन');
  String get navAccounts => _t('Accounts', 'खाते');
  String get navCategories => _t('Categories', 'श्रेणियाँ');
  String get navBills => _t('Bills', 'बिल');
  String get navGoals => _t('Goals', 'लक्ष्य');
  String get navAnalytics => _t('Analytics', 'एनालिटिक्स');
  String get navCalendar => _t('Calendar', 'कैलेंडर');
  String get navAi => _t('AI Assistant', 'एआई सहायक');
  String get navSettings => _t('Settings', 'सेटिंग्स');

  // —— Auth ——
  String get login => _t('Log in', 'लॉग इन');
  String get register => _t('Create account', 'खाता बनाएँ');
  String get email => _t('Email', 'ईमेल');
  String get password => _t('Password', 'पासवर्ड');
  String get name => _t('Name', 'नाम');
  String get continueGoogle => _t('Continue with Google', 'Google से जारी रखें');
  String get forgotPassword => _t('Forgot password?', 'पासवर्ड भूल गए?');
  String get signOutConfirm =>
      _t('Log out?', 'लॉग आउट करें?');
  String get signOutBody => _t(
        'You can sign back in anytime with the same account.',
        'आप किसी भी समय उसी खाते से फिर साइन इन कर सकते हैं।',
      );
  String get signingOut => _t('Signing out…', 'साइन आउट हो रहा है…');

  // —— Budgets ——
  String get budgetsTitle => _t('Budgets', 'बजट');
  String get noBudgets => _t('No budgets yet', 'अभी कोई बजट नहीं');
  String get noBudgetsHint => _t(
        'Set monthly or weekly spending limits',
        'मासिक या साप्ताहिक खर्च सीमा सेट करें',
      );
  String get createBudget => _t('Create budget', 'बजट बनाएँ');
  String get newBudget => _t('New budget', 'नया बजट');
  String get limit => _t('Limit', 'सीमा');
  String get period => _t('Period', 'अवधि');
  String get weekly => _t('Weekly', 'साप्ताहिक');
  String get monthly => _t('Monthly', 'मासिक');
  String get categoryOptional =>
      _t('Category (optional)', 'श्रेणी (वैकल्पिक)');
  String get liveFromActivity => _t(
        'Progress updates from your expenses',
        'प्रगति आपके खर्चों से अपडेट होती है',
      );

  // —— Settings ——
  String get biometric => _t('Biometric login', 'बायोमेट्रिक लॉगिन');
  String get biometricHint => _t(
        'Require fingerprint / Face ID on open',
        'खोलते समय फिंगरप्रिंट / फेस आईडी आवश्यक',
      );
  String get pinLock => _t('PIN lock', 'पिन लॉक');
  String get downloadActivity =>
      _t('Download activity (CSV)', 'गतिविधि डाउनलोड (CSV)');
  String get downloadActivityHint =>
      _t('Save all transactions to a file', 'सभी लेन-देन फ़ाइल में सहेजें');
  String get backupSync => _t('Backup / sync', 'बैकअप / सिंक');
  String get deleteAccount => _t('Delete account', 'खाता हटाएँ');
  String get noTxDownload =>
      _t('No transactions to download', 'डाउनलोड करने के लिए कोई लेन-देन नहीं');

  // —— AI ——
  String get aiTitle => _t('AI Assistant', 'एआई सहायक');
  String get aiChatSubtitle =>
      _t('Chat about your money', 'अपने पैसे के बारे में चैट करें');
  String get aiNewChat => _t('New chat', 'नई चैट');
  String get aiHint => _t(
        'Type your question or request a PDF/CSV report…',
        'अपना प्रश्न लिखें या PDF/CSV रिपोर्ट माँगें…',
      );
  String get aiTypeHint => _t(
        'Write freely — ask about the app, your spending, or request a report.',
        'खुलकर लिखें — ऐप, खर्च या रिपोर्ट के बारे में पूछें।',
      );
  String get aiSend => _t('Send', 'भेजें');
  String get aiWelcome => _t(
        'Hi! I know LedgerOne inside-out. Ask how to use any feature, analyze your money, or say “create a PDF/CSV report”.',
        'नमस्ते! मुझे LedgerOne की पूरी जानकारी है। कोई भी फीचर पूछें, खर्च विश्लेषण करें, या “PDF/CSV रिपोर्ट बनाओ” कहें।',
      );
  String get navChat => _t('Chat', 'चैट');
  String get downloadReport => _t('Download report', 'रिपोर्ट डाउनलोड');
  String get downloadPdf => _t('Download PDF', 'PDF डाउनलोड');
  String get downloadCsv => _t('Download CSV', 'CSV डाउनलोड');
  String get downloadBoth => _t('Download PDF + CSV', 'PDF + CSV डाउनलोड');
  String get shareReport => _t('Share', 'शेयर');
  String get sharePdf => _t('Share PDF', 'PDF शेयर');
  String get shareCsv => _t('Share CSV', 'CSV शेयर');
  String get shareBoth => _t('Share PDF + CSV', 'PDF + CSV शेयर');
  String get exportData => _t('Export & share', 'एक्सपोर्ट और शेयर');
  String get exportPdfHint =>
      _t('Activity statement as PDF', 'गतिविधि स्टेटमेंट PDF');
  String get exportCsvHint =>
      _t('All transactions as CSV', 'सभी लेन-देन CSV');
  String get exportShareHint =>
      _t('Share PDF or CSV with others', 'PDF या CSV दूसरों के साथ शेयर करें');

  String get aiRateLimited => _t(
        'AI rate limit reached. Please wait a moment.',
        'एआई सीमा पूरी हो गई। थोड़ी देर प्रतीक्षा करें।',
      );
  String get aiUnavailable => _t(
        'AI is unavailable. Enable Gemini Developer API in Firebase Console → AI Logic.',
        'एआई उपलब्ध नहीं है। Firebase Console → AI Logic में Gemini Developer API चालू करें।',
      );

  // —— Dashboard ——
  String get balance => _t('Balance', 'शेष राशि');
  String get income => _t('Income', 'आय');
  String get expense => _t('Expense', 'खर्च');
  String get aiInsight => _t('AI Insight', 'एआई इनसाइट');
  String get recentActivity => _t('Recent activity', 'हाल की गतिविधि');

  // —— Transactions ——
  String get transactionsTitle => _t('Transactions', 'लेन-देन');
  String get searchTx =>
      _t('Search merchant, notes, amount…', 'व्यापारी, नोट्स, राशि खोजें…');
  String get all => _t('All', 'सभी');

  // —— Profile ——
  String get phone => _t('Phone', 'फ़ोन');
  String get timezone => _t('Timezone', 'समय क्षेत्र');
  String get photoUpdated => _t('Photo updated', 'फ़ोटो अपडेट हुई');
  String get photoFailed => _t('Could not upload photo', 'फ़ोटो अपलोड नहीं हो सकी');
}

final l10nProvider = Provider<AppL10n>((ref) {
  final lang =
      ref.watch(settingsProvider).asData?.value.language ?? 'en';
  return AppL10n(lang == 'hi' ? 'hi' : 'en');
});

extension AppL10nX on WidgetRef {
  AppL10n get l10n => watch(l10nProvider);
}
