import '../../features/transactions/domain/money_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_l10n.dart';
import '../utils/csv_export.dart';
import '../utils/report_export.dart';
import '../../features/accounts/data/accounts_repository.dart';
import '../../features/budgets/data/budgets_repository.dart';
import '../../features/categories/data/categories_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/transactions/data/transactions_repository.dart';

Future<void> showExportShareSheet(
  BuildContext context,
  WidgetRef ref, {
  List<MoneyTransaction>? selectedTransactions,
  String scopeLabel = 'All activity',
}) async {
  try {
    final l10n = ref.read(l10nProvider);
    final List<MoneyTransaction> txs =
        selectedTransactions ?? (await ref.read(transactionsProvider.future));
    if (!context.mounted) return;
    final cats = ref.read(categoriesProvider).asData?.value ?? [];
    final accounts = ref.read(accountsProvider).asData?.value ?? [];
    final budgets =
        ref.read(liveBudgetsProvider).asData?.value ??
        ref.read(budgetsProvider).asData?.value ??
        [];
    final currency = ref.read(settingsProvider).asData?.value.currency ?? 'INR';

    if (txs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noTxDownload)));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${l10n.exportData} ? $scopeLabel (${txs.length})',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(l10n.downloadPdf),
                  subtitle: Text(l10n.exportPdfHint),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final msg = await downloadTransactionsPdf(
                        transactions: txs,
                        categories: cats,
                        accounts: accounts,
                        budgets: budgets,
                        currency: currency,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download failed: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: Text(l10n.downloadCsv),
                  subtitle: Text(l10n.exportCsvHint),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final msg = await downloadTransactionsCsv(
                        transactions: txs,
                        categories: cats,
                        accounts: accounts,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download failed: $e')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: Text(l10n.shareReport),
                  subtitle: Text(l10n.exportShareHint),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      final bundle = await buildActivityReport(
                        transactions: txs,
                        categories: cats,
                        accounts: accounts,
                        budgets: budgets,
                        currency: currency,
                        format: ReportFormat.both,
                      );
                      final msg = await shareReportBundle(bundle);
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(msg)));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Share failed: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare export: $error')),
      );
    }
  }
}
