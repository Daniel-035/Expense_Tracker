import 'money.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../features/accounts/domain/account.dart';
import '../../features/budgets/domain/budget.dart';
import '../../features/categories/domain/category.dart';
import '../../features/transactions/domain/money_transaction.dart';
import 'csv_export.dart';

enum ReportFormat { csv, pdf, both }

class ReportBundle {
  const ReportBundle({
    required this.title,
    this.csvBytes,
    this.pdfBytes,
    this.csvFileName,
    this.pdfFileName,
  });

  final String title;
  final Uint8List? csvBytes;
  final Uint8List? pdfBytes;
  final String? csvFileName;
  final String? pdfFileName;

  bool get hasCsv => csvBytes != null;
  bool get hasPdf => pdfBytes != null;
}

String _stamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

Future<String> saveBytesFile({
  required String name,
  required Uint8List bytes,
  required String extension,
  required MimeType mimeType,
}) async {
  final path = await FileSaver.instance.saveFile(
    name: name,
    bytes: bytes,
    fileExtension: extension,
    mimeType: mimeType,
  );
  final file = '$name.$extension';
  if (kIsWeb) return 'Downloaded $file';
  return path.isEmpty ? 'Saved $file' : 'Saved to $path';
}

Future<String> shareBytesFile({
  required String name,
  required Uint8List bytes,
  required String extension,
  required String mime,
  String? subject,
}) async {
  final xFile = XFile.fromData(bytes, mimeType: mime, name: '$name.$extension');
  await SharePlus.instance.share(
    ShareParams(
      files: [xFile],
      subject: subject ?? name,
      text: 'LedgerOne report: $name.$extension',
    ),
  );
  return 'Shared $name.$extension';
}

Future<Uint8List> buildActivityPdfBytes({
  required List<MoneyTransaction> transactions,
  required List<Category> categories,
  required List<Account> accounts,
  List<Budget> budgets = const [],
  String currency = 'INR',
  String title = 'LedgerOne Activity Report',
  String? narrative,
}) async {
  final catMap = {for (final c in categories) c.id: c.name};
  final sorted = [...transactions]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  var income = 0.0;
  var expense = 0.0;
  for (final t in sorted) {
    if (t.createdAt.isBefore(monthStart)) continue;
    if (t.transactionType == TransactionType.income) {
      income = Money.add(income, t.amount);
    }
    if (t.transactionType == TransactionType.expense) {
      expense = Money.add(expense, t.amount);
    }
  }
  final balance = accounts.fold<double>(0, (s, a) => Money.add(s, a.balance));
  final liveBudgets = budgets.map((b) => b.withLiveSpent(sorted)).toList();

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF2563EB),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated ${DateFormat.yMMMd().add_jm().format(now)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Divider(),
        ],
      ),
      build: (context) => [
        if (narrative != null && narrative.trim().isNotEmpty) ...[
          pw.Text(
            'Summary',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(narrative.trim(), style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 16),
        ],
        pw.Text(
          'Overview',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Bullet(text: 'Currency: $currency'),
        pw.Bullet(text: 'Total balance: ${balance.toStringAsFixed(2)}'),
        pw.Bullet(text: 'This month income: ${income.toStringAsFixed(2)}'),
        pw.Bullet(text: 'This month expense: ${expense.toStringAsFixed(2)}'),
        pw.Bullet(
          text:
              'Net this month: ${(income - expense).toStringAsFixed(2)} · Transactions: ${sorted.length}',
        ),
        if (liveBudgets.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Budgets',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...liveBudgets.map(
            (b) => pw.Bullet(
              text:
                  '${b.period.name} · spent ${b.spent.toStringAsFixed(0)} / ${b.amount.toStringAsFixed(0)}'
                  '${b.isExceeded ? " (exceeded)" : ""}',
            ),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(
          'Activity',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (sorted.isEmpty)
          pw.Text('No transactions yet.')
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Type', 'Amount', 'Category', 'Merchant'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF2563EB),
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            data: sorted
                .take(80)
                .map(
                  (t) => [
                    DateFormat.yMMMd().format(t.createdAt),
                    t.transactionType.name,
                    t.amount.toStringAsFixed(2),
                    catMap[t.categoryId] ?? '',
                    (t.merchant ?? '').length > 24
                        ? '${t.merchant!.substring(0, 24)}…'
                        : (t.merchant ?? ''),
                  ],
                )
                .toList(),
          ),
        if (sorted.length > 80)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Showing first 80 of ${sorted.length} transactions. Use CSV for the full export.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ),
      ],
      footer: (context) => pw.Text(
        'LedgerOne · Page ${context.pageNumber}/${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    ),
  );
  return doc.save();
}

Future<ReportBundle> buildActivityReport({
  required List<MoneyTransaction> transactions,
  required List<Category> categories,
  required List<Account> accounts,
  List<Budget> budgets = const [],
  String currency = 'INR',
  String title = 'LedgerOne Activity Report',
  String? narrative,
  ReportFormat format = ReportFormat.both,
}) async {
  final stamp = _stamp();
  Uint8List? csvBytes;
  Uint8List? pdfBytes;
  String? csvName;
  String? pdfName;

  if (format == ReportFormat.csv || format == ReportFormat.both) {
    final csv = buildTransactionsCsv(
      transactions: transactions,
      categories: categories,
      accounts: accounts,
    );
    csvBytes = Uint8List.fromList(utf8.encode(csv));
    csvName = 'ledgerone_activity_$stamp';
  }
  if (format == ReportFormat.pdf || format == ReportFormat.both) {
    pdfBytes = await buildActivityPdfBytes(
      transactions: transactions,
      categories: categories,
      accounts: accounts,
      budgets: budgets,
      currency: currency,
      title: title,
      narrative: narrative,
    );
    pdfName = 'ledgerone_report_$stamp';
  }

  return ReportBundle(
    title: title,
    csvBytes: csvBytes,
    pdfBytes: pdfBytes,
    csvFileName: csvName,
    pdfFileName: pdfName,
  );
}

Future<String> downloadReportBundle(
  ReportBundle bundle, {
  ReportFormat prefer = ReportFormat.both,
}) async {
  final parts = <String>[];
  if ((prefer == ReportFormat.csv || prefer == ReportFormat.both) &&
      bundle.csvBytes != null) {
    parts.add(
      await saveBytesFile(
        name: bundle.csvFileName ?? 'ledgerone_activity',
        bytes: bundle.csvBytes!,
        extension: 'csv',
        mimeType: MimeType.csv,
      ),
    );
  }
  if ((prefer == ReportFormat.pdf || prefer == ReportFormat.both) &&
      bundle.pdfBytes != null) {
    parts.add(
      await saveBytesFile(
        name: bundle.pdfFileName ?? 'ledgerone_report',
        bytes: bundle.pdfBytes!,
        extension: 'pdf',
        mimeType: MimeType.pdf,
      ),
    );
  }
  return parts.isEmpty ? 'Nothing to download' : parts.join(' · ');
}

Future<String> shareReportBundle(
  ReportBundle bundle, {
  ReportFormat prefer = ReportFormat.both,
}) async {
  final files = <XFile>[];
  if ((prefer == ReportFormat.csv || prefer == ReportFormat.both) &&
      bundle.csvBytes != null) {
    files.add(
      XFile.fromData(
        bundle.csvBytes!,
        mimeType: 'text/csv',
        name: '${bundle.csvFileName ?? 'ledgerone_activity'}.csv',
      ),
    );
  }
  if ((prefer == ReportFormat.pdf || prefer == ReportFormat.both) &&
      bundle.pdfBytes != null) {
    files.add(
      XFile.fromData(
        bundle.pdfBytes!,
        mimeType: 'application/pdf',
        name: '${bundle.pdfFileName ?? 'ledgerone_report'}.pdf',
      ),
    );
  }
  if (files.isEmpty) return 'Nothing to share';
  await SharePlus.instance.share(
    ShareParams(files: files, subject: bundle.title, text: bundle.title),
  );
  return 'Shared ${files.length} file(s)';
}

Future<String> downloadTransactionsPdf({
  required List<MoneyTransaction> transactions,
  required List<Category> categories,
  List<Account> accounts = const [],
  List<Budget> budgets = const [],
  String currency = 'INR',
}) async {
  final bundle = await buildActivityReport(
    transactions: transactions,
    categories: categories,
    accounts: accounts,
    budgets: budgets,
    currency: currency,
    format: ReportFormat.pdf,
  );
  return downloadReportBundle(bundle, prefer: ReportFormat.pdf);
}
