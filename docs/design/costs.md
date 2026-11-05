# Costs, currencies and splitting

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for currencies, totals, expense splitting, settlements, reimbursements, invitations.

- **Currencies are a user-managed table too**, on the same pattern as the transport modes: a
  cost's `Costs.currency` is a foreign key into `Currencies`, and the `Currency` enum is only
  the *catalog of built-ins* (EUR/USD/GBP/CHF) the DB is seeded with, in enum order, so a
  fresh row's id is its enum index + 1 — what the v23 migration repoints legacy costs by. A
  row's identity is its unique `code`; unlike a mode, a currency in use **cannot be deleted**
  (`restrict`, plus a check in `CurrencyDao`) — a leg without a mode is still a leg, an amount
  without a currency is nothing. Exactly one row `isBase`, and every other carries an optional
  `rateMicros`: what one of its units is worth in the base, in millionths (`kRateOne`), or null
  for "not set" — the app then declines to convert rather than guessing. `CurrencyDao.setBase`
  re-expresses every rate against the new base (clearing them when the new base has no rate to
  divide by; `rebaseClearsRates` warns first). CRUD is in `CurrencyDao`, the UI in
  `features/costs/presentation/currencies_settings.dart`.
- **The maths stays per-currency; conversion is only ever an extra line.** `core/format/money_format.dart`
  holds the pure `CurrencyInfo` / `CurrencyBook` — a lookup by row id *and* by code, plus the
  base and the display order — that everything printing money reads (`currencyBookProvider`;
  the PDF and `.ics` build one from `TripBundle.currencyBook` instead). Totals are keyed by
  currency **code**, not row id, so one map shape serves both the app and a shared trip.
  `formatTotals` appends "≈ €395.90" when several currencies are involved *and* every one has
  a rate — never replacing the exact per-currency figures, and never on a partial set, which
  would read as a total while leaving money out. `computeTripStats` still converts nothing.

- **Expense splitting** lives in `lib/features/costs/trip_stats.dart` as pure functions
  (`computeTripStats`) so the per-currency category breakdown, per-person paid/share/balance,
  and minimal settle-up transfers are unit-testable without a database. A cost splits among
  its `CostBeneficiaries`, falling back to all trip participants. Nothing here converts between
  currencies — everything is computed per currency code, in the `CurrencyBook`'s order.
- **A settlement is a `Costs` row that isn't spending.** `Costs.isTransfer` marks money handed
  from one person to another to square up: always trip-level, `paidBy` the sender, its single
  beneficiary the receiver, and no `reason` (a repayment is not a category). It moves the two
  balances and nothing else — `computeTripStats` keeps it out of `totalMinor`, the paid/open
  split, the expense `count`, and the categories, folding it instead into
  `PersonStat.settledMinor` (sent − received), which `netMinor` adds to `paid − share`. So
  "paid" still means "spent on the trip" and still sums to the trip's total, while the
  settle-up list — unchanged, it just reads `netMinor` — shrinks by what has been paid back.
  Unlike an expense, a settlement with no beneficiary recorded does **not** fall back to the
  participants: it would otherwise quietly spread itself over everyone. The same rule is
  mirrored wherever money is summed: `sumByCurrency` (every "Total" the app prints) and
  `CostDao.watchTotalsByTrip` (overview cards) drop transfers, while
  `watchCountedCostsForTrip` keeps them — they are what settles the balances. Recording one
  goes through `CostController.addTransfer` / `showTransferFormSheet` (a "from → to" form, no
  category, no split), reachable from the trip's general expenses and, prefilled, from each
  suggested payment in the settle-up list.
- **A reimbursement is a settlement from outside the group** (`Costs.isReimbursement`, v37,
  only ever set together with `isTransfer`): an employer's flat allowance, an insurer. It has
  a settlement's shape — `paidBy` the source, one beneficiary the receiver — and, as the one
  thing a settlement cannot say, moves **no** balance. Booked as an ordinary settlement it
  left the receiver owing the source exactly what the source had paid them. It is a flag on
  the settlement and not a flag on the expenses it covers, because allowances are flat sums
  that belong to no expense and match none in amount. `computeTripStats` reports it beside
  the balances instead: `PersonStat.reimbursedMinor` for the receiver, and
  `CurrencyStats.reimbursementsBySource` per source, which `mergeTripStats` pools — "how much
  has my employer paid back this year" is the question the all-trips reading answers. The
  source is **not** in `byPerson`: it neither paid for nor benefited from anything on the
  trip. It belongs to its receiver alone, so a traveler whose allowance covers a dinner they
  paid for somebody else is still owed that somebody's share. The flag is a form field, not
  fixed at opening like `isTransfer`, since an allowance already booked as a settlement is
  corrected by ticking it. `CostController.addTransfer`/`updateTransfer` are its only
  writers, and the importer drops it off anything that is not a transfer. A trip holding one
  goes out as `.tpt` **v5**, because an older app would read it as a settlement and show the
  debt.
- **An invitation is a property of the split, not of the cost** (`CostBeneficiaries.invited`,
  v38): the payer paid for this beneficiary and does not want it back. Per beneficiary so one
  dinner can hold a guest and somebody who repays without being cut in two. The share stays
  the guest's — `shareMinor`, the totals and the categories do not move, since the money was
  spent all the same — and `computeTripStats` books it to the guest's `invitedMinor` and the
  payer's `hostedMinor`, which `borneMinor` (what somebody's expenses came to in the end) and
  so `netMinor` read. It means something only on an expense **with a payer**, for a
  beneficiary **other than the payer**, and on an **explicit** split — the participant
  fallback names nobody to invite — so the stats ignore it anywhere else, and
  `CostController._guestsOf` and the importer never store it there. The form marks it on the
  "paid for" chips (tap to toggle, a giving hand for the avatar) plus a tristate *Invited by {payer}*
  box that invites or clears everyone at once. It rides with a routine's fare, since a
  colleague whose ticket is always on you is invited every morning. A trip with one goes out
  as `.tpt` **v6**, stamped only then, because an older app would show the guest owing their
  share. The PDF is untouched: it prints no split and no balance, and an invitation changes
  neither the total nor any row.
