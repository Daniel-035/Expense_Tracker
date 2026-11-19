import '../../../../shared/widgets/async_action_button.dart';
import '../../../../core/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/common_widgets.dart';
import '../../data/categories_repository.dart';
import '../../domain/category.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppText('Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showForm(context, ref),
          ),
        ],
      ),
      body: catsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => Center(child: Text('$e')),
        data: (cats) {
          final income = cats
              .where((c) => c.type == CategoryType.income)
              .toList();
          final expense = cats
              .where((c) => c.type == CategoryType.expense)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionHeader('Income'),
              ...income.map((c) => _tile(context, ref, c)),
              const SectionHeader('Expense'),
              ...expense.map((c) => _tile(context, ref, c)),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, WidgetRef ref, Category c) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Color(c.color).withValues(alpha: 0.2),
          child: Icon(Icons.category, color: Color(c.color)),
        ),
        title: Text(c.name),
        subtitle: Text(c.isSystem ? 'System' : 'Custom'),
        trailing: c.isSystem
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => confirmMutation(
                  context,
                  title: 'Delete category?',
                  action: () =>
                      ref.read(categoriesRepositoryProvider).delete(c.id),
                ),
              ),
        onTap: c.isSystem ? null : () => _showForm(context, ref, category: c),
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
  }) async {
    final name = TextEditingController(text: category?.name);
    var type = category?.type ?? CategoryType.expense;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category == null ? 'Add category' : 'Edit category',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: AppText.translate(context, 'Name'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<CategoryType>(
                    segments: const [
                      ButtonSegment(
                        value: CategoryType.expense,
                        label: AppText('Expense'),
                      ),
                      ButtonSegment(
                        value: CategoryType.income,
                        label: AppText('Income'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setModal(() => type = s.first),
                  ),
                  const SizedBox(height: 16),
                  AsyncActionButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      if (category == null) {
                        await ref
                            .read(categoriesRepositoryProvider)
                            .create(
                              name: name.text.trim(),
                              type: type,
                              color: 0xFF0D7377,
                              icon: 'category',
                            );
                      } else {
                        await ref
                            .read(categoriesRepositoryProvider)
                            .update(
                              Category(
                                id: category.id,
                                name: name.text.trim(),
                                type: type,
                                color: category.color,
                                icon: category.icon,
                                isSystem: false,
                              ),
                            );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const AppText('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
