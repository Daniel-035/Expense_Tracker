import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import '../../features/accounts/domain/account.dart';
import '../../features/categories/domain/category.dart';
import '../../features/transactions/domain/money_transaction.dart';

String buildTransactionsCsv({
  required List<MoneyTransaction> transactions,
  required List<Category> categories,
  List<Account> accounts = const [],
}) {
  final catMap = {for (final c in categories) c.id: c.name};
  final accountMap = {for (final a in accounts) a.id: a.accountName};
  final buf = StringBuffer();
  buf.writeln(
    'date,type,amount,category,account,merchant,notes,location,tags,id',
  );
  final sorted = [...transactions]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  for (final t in sorted) {
    final row = [
      t.createdAt.toIso8601String(),
      t.transactionType.name,
      t.amount.toStringAsFixed(2),
      _csv(catMap[t.categoryId] ?? ''),
      _csv(accountMap[t.accountId] ?? t.accountId),
      _csv(t.merchant ?? ''),
      _csv(t.notes ?? ''),
      _csv(t.location ?? ''),
      _csv(t.tags.join(';')),
      t.id,
    ].join(',');
    buf.writeln(row);
  }
  return buf.toString();
}

String _csv(String value) => '"${value.replaceAll('"', '""')}"';

/// Saves activity CSV to a downloadable file (web download / mobile save).
Future<String> downloadTransactionsCsv({
  required List<MoneyTransaction> transactions,
  required List<Category> categories,
  List<Account> accounts = const [],
}) async {
  final csv = buildTransactionsCsv(
    transactions: transactions,
    categories: categories,
    accounts: accounts,
  );
  final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final name = 'ledgerone_activity_$stamp';
  final bytes = Uint8List.fromList(utf8.encode(csv));

  final path = await FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: 'csv',
    mimeType: MimeType.csv,
  );

  if (kIsWeb) {
    return 'Downloaded $name.csv';
  }
  return path.isEmpty ? 'Saved $name.csv' : 'Saved to $path';
}
