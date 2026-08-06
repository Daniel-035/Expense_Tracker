class DefaultCategoryDef {
  const DefaultCategoryDef({
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
  });

  final String name;
  final String type; // income | expense
  final int color;
  final String icon;
}

const List<DefaultCategoryDef> kDefaultCategories = [
  // Income
  DefaultCategoryDef(
    name: 'Salary',
    type: 'income',
    color: 0xFF2E7D32,
    icon: 'payments',
  ),
  DefaultCategoryDef(
    name: 'Freelance',
    type: 'income',
    color: 0xFF00897B,
    icon: 'work',
  ),
  DefaultCategoryDef(
    name: 'Business',
    type: 'income',
    color: 0xFF1565C0,
    icon: 'business',
  ),
  DefaultCategoryDef(
    name: 'Investment',
    type: 'income',
    color: 0xFF6A1B9A,
    icon: 'trending_up',
  ),
  DefaultCategoryDef(
    name: 'Interest',
    type: 'income',
    color: 0xFF4527A0,
    icon: 'account_balance',
  ),
  DefaultCategoryDef(
    name: 'Gift',
    type: 'income',
    color: 0xFFC2185B,
    icon: 'card_giftcard',
  ),
  DefaultCategoryDef(
    name: 'Other Income',
    type: 'income',
    color: 0xFF546E7A,
    icon: 'more_horiz',
  ),
  // Expense
  DefaultCategoryDef(
    name: 'Food',
    type: 'expense',
    color: 0xFFE65100,
    icon: 'restaurant',
  ),
  DefaultCategoryDef(
    name: 'Grocery',
    type: 'expense',
    color: 0xFFEF6C00,
    icon: 'local_grocery_store',
  ),
  DefaultCategoryDef(
    name: 'Fuel',
    type: 'expense',
    color: 0xFFBF360C,
    icon: 'local_gas_station',
  ),
  DefaultCategoryDef(
    name: 'Rent',
    type: 'expense',
    color: 0xFF5D4037,
    icon: 'home',
  ),
  DefaultCategoryDef(
    name: 'Shopping',
    type: 'expense',
    color: 0xFFAD1457,
    icon: 'shopping_bag',
  ),
  DefaultCategoryDef(
    name: 'EMI',
    type: 'expense',
    color: 0xFF283593,
    icon: 'credit_card',
  ),
  DefaultCategoryDef(
    name: 'Utilities',
    type: 'expense',
    color: 0xFF0277BD,
    icon: 'bolt',
  ),
  DefaultCategoryDef(
    name: 'Medical',
    type: 'expense',
    color: 0xFFC62828,
    icon: 'medical_services',
  ),
  DefaultCategoryDef(
    name: 'Education',
    type: 'expense',
    color: 0xFF00695C,
    icon: 'school',
  ),
  DefaultCategoryDef(
    name: 'Entertainment',
    type: 'expense',
    color: 0xFF6A1B9A,
    icon: 'movie',
  ),
  DefaultCategoryDef(
    name: 'Travel',
    type: 'expense',
    color: 0xFF0288D1,
    icon: 'flight',
  ),
  DefaultCategoryDef(
    name: 'Miscellaneous',
    type: 'expense',
    color: 0xFF607D8B,
    icon: 'category',
  ),
];
