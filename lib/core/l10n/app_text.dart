import 'package:flutter/material.dart';

/// Localizes shared static screen labels using the app's selected locale.
class AppText extends StatelessWidget {
  const AppText(this.label, {super.key});
  final String label;
  static const _hindi = <String, String>{
    'Name': 'नाम',
    'Title': 'शीर्षक',
    'Amount': 'राशि',
    'Type': 'प्रकार',
    'Opening balance': 'शुरुआती शेष राशि',
    'From': 'से',
    'To': 'तक',
    'To account': 'गंतव्य खाता',
    'Date & time': 'तारीख और समय',
    'Merchant / source': 'विक्रेता या स्रोत',
    'Notes': 'टिप्पणी',
    'Location': 'स्थान',
    'Tags (comma separated)': 'टैग (अल्पविराम से अलग करें)',
    'Repeat template (manual)': 'दोहराव का नमूना (मैन्युअल)',
    'Categories': 'श्रेणियाँ',
    'Confirm': 'पुष्टि करें',
    'Deposit': 'प्रगति दर्ज करें',
    'Dashboard': 'डैशबोर्ड',
    'Activity': 'गतिविधि',
    'Analytics': 'विश्लेषण',
    'Accounts': 'खाते',
    'All': 'सभी',
    'All accounts': 'सभी खाते',
    'All categories': 'सभी श्रेणियाँ',
    'Income': 'आय',
    'Expense': 'खर्च',
    'Transfer': 'स्थानांतरण',
    'Category': 'श्रेणी',
    'Account': 'खाता',
    'Save': 'सहेजें',
    'Update': 'अपडेट करें',
    'Cancel': 'रद्द करें',
    'Delete': 'हटाएँ',
    'Close': 'बंद करें',
    'Retry': 'फिर कोशिश करें',
    'Restore': 'वापस लाएँ',
    'Discard': 'हटाएँ',
    'More details': 'अधिक विवरण',
    'Keep editing': 'संपादन जारी रखें',
    'Unlock': 'अनलॉक करें',
    'Unlock LedgerOne': 'LedgerOne अनलॉक करें',
    'Use device authentication': 'डिवाइस से पहचान की पुष्टि करें',
    'Forgot PIN? Sign out and reset lock':
        'पिन भूल गए? साइन आउट करके रीसेट करें',
    'No accounts': 'कोई खाता नहीं',
    'Add account': 'खाता जोड़ें',
    'Add bill': 'बिल जोड़ें',
    'Bills & subscriptions': 'बिल और सदस्यताएँ',
    'No bills tracked': 'कोई बिल नहीं',
    'Repeats monthly': 'हर महीने दोहराएँ',
    'Due date': 'देय तारीख',
    'Confirm payment': 'भुगतान की पुष्टि करें',
    'Savings progress': 'बचत की प्रगति',
    'No goals yet': 'अभी कोई लक्ष्य नहीं',
    'Create goal': 'लक्ष्य बनाएँ',
    'Complete': 'पूरा',
    'Record progress': 'प्रगति दर्ज करें',
    'Add': 'जोड़ें',
    'Income vs expense trend': 'आय और खर्च का रुझान',
    'Spending by category': 'श्रेणी के अनुसार खर्च',
    'Cash flow': 'नकदी प्रवाह',
    'Recent transactions': 'हाल के लेन-देन',
    'See all': 'सभी देखें',
    'Receipt attached': 'रसीद संलग्न है',
    'Receipt unavailable': 'रसीद उपलब्ध नहीं',
    'Export scope': 'निर्यात का दायरा',
    'Transaction': 'लेन-देन',
    'Backup / sync': 'बैकअप और सिंक',
    'Bill reminders': 'बिल के अनुस्मारक',
    'Records an expense and updates the account balance.':
        'खर्च दर्ज होगा और खाते की शेष राशि बदलेगी।',
    'Tracks progress only; entries do not move account funds.':
        'केवल प्रगति दर्ज होती है; खाते की राशि नहीं बदलती।',
    'Repeat saves a template date. It does not post automatically.':
        'दोहराव की तारीख सहेजी जाती है। लेन-देन अपने आप दर्ज नहीं होता।',
    'Applies only to this account on this device':
        'इस डिवाइस पर केवल इस खाते के लिए',
    'Could not read device lock settings.':
        'डिवाइस लॉक की सेटिंग पढ़ी नहीं जा सकी।',
  };

  static String translate(BuildContext context, String label) =>
      Localizations.localeOf(context).languageCode == 'hi'
      ? _hindi[label] ?? label
      : label;

  @override
  Widget build(BuildContext context) => Text(translate(context, label));
}
