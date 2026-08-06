class AppConstants {
  static const String appName = 'LedgerOne';
  static const String currencyDefault = 'INR';
  static const String languageDefault = 'en';
  static const String timezoneDefault = 'Asia/Kolkata';

  static const Duration dashboardTimeout = Duration(seconds: 2);
}

class FirestorePaths {
  static String user(String uid) => 'users/$uid';
  static String accounts(String uid) => 'users/$uid/accounts';
  static String categories(String uid) => 'users/$uid/categories';
  static String transactions(String uid) => 'users/$uid/transactions';
  static String budgets(String uid) => 'users/$uid/budgets';
  static String goals(String uid) => 'users/$uid/goals';
  static String goalDeposits(String uid, String goalId) =>
      'users/$uid/goals/$goalId/deposits';
  static String bills(String uid) => 'users/$uid/bills';
  static String notifications(String uid) => 'users/$uid/notifications';
  static String settings(String uid) => 'users/$uid/settings/app';
}
