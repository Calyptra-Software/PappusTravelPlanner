import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travelplanner/core/settings/locale_provider.dart';
import 'package:travelplanner/features/costs/application/cost_display_provider.dart';
import 'package:travelplanner/features/sharing/application/pdf_sections_provider.dart';
import 'package:travelplanner/features/sharing/trip_pdf_sections.dart';

/// The settings kept in SharedPreferences, and the one rule they all share.
///
/// Every one of them is stored as an **index** — or, for the PDF, a bitmask of
/// indices — which is what makes the enums here append-only: reordering a value
/// silently rewrites what every existing install has chosen. The guard against
/// the other direction is what these tests are mostly about: a build that is
/// *older* than the one that wrote the preference reads a number it has no
/// value for, and has to fall back rather than crash.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('how a cost reason is shown', () {
    test('a fresh install shows both the icon and the words', () async {
      final container = await containerWith({});

      expect(container.read(costReasonDisplayProvider), CostReasonDisplay.both);
    });

    test('a stored choice survives the launch', () async {
      final container = await containerWith({'cost_reason_display': 0});

      expect(container.read(costReasonDisplayProvider), CostReasonDisplay.icon);
    });

    test('and is written back by index', () async {
      final container = await containerWith({});

      await container
          .read(costReasonDisplayProvider.notifier)
          .setDisplay(CostReasonDisplay.text);

      expect(container.read(costReasonDisplayProvider), CostReasonDisplay.text);
      expect(
        container.read(sharedPreferencesProvider).getInt('cost_reason_display'),
        CostReasonDisplay.text.index,
      );
    });

    test('an index this build has no value for falls back', () async {
      // What an older app reads after a newer one has appended a value.
      final container = await containerWith({'cost_reason_display': 99});

      expect(container.read(costReasonDisplayProvider), CostReasonDisplay.both);
    });

    test('and so does a negative one', () async {
      final container = await containerWith({'cost_reason_display': -1});

      expect(container.read(costReasonDisplayProvider), CostReasonDisplay.both);
    });
  });

  group('which expenses the overview totals', () {
    test('all of them, until told otherwise', () async {
      final container = await containerWith({});

      expect(container.read(expenseScopeProvider), ExpenseScope.all);
    });

    test(
      'a stored choice survives the launch, and is written by index',
      () async {
        final container = await containerWith({});

        await container
            .read(expenseScopeProvider.notifier)
            .setScope(ExpenseScope.mine);

        expect(container.read(expenseScopeProvider), ExpenseScope.mine);
        expect(
          container.read(sharedPreferencesProvider).getInt('expense_scope'),
          ExpenseScope.mine.index,
        );
      },
    );

    test('an unknown index falls back', () async {
      final container = await containerWith({'expense_scope': 7});

      expect(container.read(expenseScopeProvider), ExpenseScope.all);
    });
  });

  group('what the PDF prints', () {
    test('a fresh install leaves the photographs off', () async {
      final container = await containerWith({});

      // Every other section costs a few kilobytes of text; this one can turn a
      // two-page itinerary into a document too large to mail.
      expect(container.read(pdfSectionsProvider), kDefaultPdfSections);
      expect(kDefaultPdfSections, isNot(contains(PdfSection.photos)));
    });

    test('a choice round-trips through the bitmask', () async {
      final container = await containerWith({});

      await container.read(pdfSectionsProvider.notifier).setSections({
        PdfSection.itinerary,
        PdfSection.photos,
      });

      expect(container.read(pdfSectionsProvider), {
        PdfSection.itinerary,
        PdfSection.photos,
      });
      expect(
        container.read(sharedPreferencesProvider).getInt('pdf_sections'),
        (1 << PdfSection.itinerary.index) | (1 << PdfSection.photos.index),
      );
    });

    test('bits this build knows nothing about are simply not read', () async {
      // A newer build's fifth section, plus this build's first.
      final container = await containerWith({
        'pdf_sections': (1 << PdfSection.itinerary.index) | (1 << 9),
      });

      expect(container.read(pdfSectionsProvider), {PdfSection.itinerary});
    });

    test('a mask naming nothing this build has falls back', () async {
      final container = await containerWith({'pdf_sections': 1 << 9});

      // An export of nothing is not an export, so what a fresh install prints
      // is the better answer than an empty document.
      expect(container.read(pdfSectionsProvider), kDefaultPdfSections);
    });

    test('and so does a mask of zero', () async {
      final container = await containerWith({'pdf_sections': 0});

      expect(container.read(pdfSectionsProvider), kDefaultPdfSections);
    });
  });
}
