import '../../core/l10n/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget? dataStatus(List<AsyncValue<Object?>> values, VoidCallback retry) {
  if (values.any((v) => v.hasError)) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load your data. Your saved entries have not been changed.',
            ),
            TextButton(onPressed: retry, child: const AppText('Retry')),
          ],
        ),
      ),
    );
  }
  if (values.any((v) => !v.hasValue)) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  return null;
}
