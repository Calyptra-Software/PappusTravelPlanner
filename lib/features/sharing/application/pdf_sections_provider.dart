import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/locale_provider.dart'
    show sharedPreferencesProvider;
import '../trip_pdf_sections.dart';

/// The sections the user last exported, remembered across launches: someone who
/// prints the itinerary for the road does it every trip, and re-ticking the
/// boxes each time is the friction that makes a feature go unused.
///
/// Stored as a **bitmask** of [PdfSection] indices, so — like every other
/// persisted enum here — values may only be appended to the enum, never
/// reordered. Mirrors `CostReasonDisplayController`.
final pdfSectionsProvider =
    NotifierProvider<PdfSectionsController, Set<PdfSection>>(
      PdfSectionsController.new,
    );

class PdfSectionsController extends Notifier<Set<PdfSection>> {
  static const _key = 'pdf_sections';

  @override
  Set<PdfSection> build() {
    final mask = ref.read(sharedPreferencesProvider).getInt(_key);
    if (mask == null) return kDefaultPdfSections;
    final stored = {
      for (final section in PdfSection.values)
        if (mask & (1 << section.index) != 0) section,
    };
    // An empty mask can only come from a build that knew sections this one
    // doesn't; falling back to what a fresh install prints beats offering an
    // export of nothing.
    return stored.isEmpty ? kDefaultPdfSections : stored;
  }

  Future<void> setSections(Set<PdfSection> sections) async {
    var mask = 0;
    for (final section in sections) {
      mask |= 1 << section.index;
    }
    await ref.read(sharedPreferencesProvider).setInt(_key, mask);
    state = {...sections};
  }
}
