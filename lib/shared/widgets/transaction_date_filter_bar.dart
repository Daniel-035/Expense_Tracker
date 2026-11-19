import '../../core/l10n/app_text.dart';
import 'package:flutter/material.dart';

import '../filters/transaction_date_filter.dart';

class TransactionDateFilterBar extends StatelessWidget {
  const TransactionDateFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TransactionDateFilter value;
  final ValueChanged<TransactionDateFilter> onChanged;

  Future<void> _selectPreset(
    BuildContext context,
    DateFilterPreset preset,
  ) async {
    if (preset != DateFilterPreset.custom) {
      onChanged(value.withPreset(preset));
      return;
    }

    final currentRange = value.range;
    final initialRange = DateTimeRange(
      start: currentRange.start,
      end: currentRange.end.subtract(const Duration(days: 1)),
    );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: initialRange,
      helpText: 'Select transaction dates',
    );
    if (picked != null) {
      onChanged(TransactionDateFilter.custom(picked.start, picked.end));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<DateFilterPreset>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: DateFilterPreset.day, label: AppText('Day')),
              ButtonSegment(
                value: DateFilterPreset.month,
                label: AppText('Month'),
              ),
              ButtonSegment(
                value: DateFilterPreset.year,
                label: AppText('Year'),
              ),
              ButtonSegment(
                value: DateFilterPreset.custom,
                label: AppText('Dates'),
                icon: Icon(Icons.date_range_outlined),
              ),
            ],
            selected: {value.preset},
            onSelectionChanged: (selection) {
              _selectPreset(context, selection.first);
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous period',
              onPressed: value.preset == DateFilterPreset.custom
                  ? null
                  : () => onChanged(value.shift(-1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: value.preset == DateFilterPreset.custom
                    ? () => _selectPreset(context, DateFilterPreset.custom)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    value.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next period',
              onPressed: value.preset == DateFilterPreset.custom
                  ? null
                  : () => onChanged(value.shift(1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
