import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/search_picker.dart';
import '../application/cost_providers.dart';

/// Picks a person from the shared roster — a searchable list of everyone not
/// already in [currentNames], where a name nobody on it has can be added right
/// from the search box. Watches the roster live so the list fills in as soon as
/// it loads. Resolves to the chosen name, or null if dismissed.
Future<String?> showPersonPicker(
  BuildContext context, {
  required Set<String> currentNames,
  required String title,
}) async {
  final result = await showSearchPickerSheet(
    context,
    (context) => Consumer(
      builder: (context, ref, _) {
        final roster = ref.watch(peopleProvider).value ?? const <String>[];
        final meName = ref.watch(mePersonProvider).value?.name;
        return SearchPickerSheet(
          title: title,
          options: [
            for (final name in roster)
              if (!currentNames.contains(name))
                SearchPickerOption(
                  name,
                  icon: name == meName ? Icons.person : Icons.person_outline,
                ),
          ],
          textCapitalization: TextCapitalization.words,
        );
      },
    ),
  );
  return result?.value;
}
