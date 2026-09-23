# Retired migration: 20260901220000

`20260901220000_transition_based_colocation.sql` was committed as an attempt to remove the two-hour same-city expiry, but it was never applied to the hosted App database. It replaced `recompute_colocation_for_pair`, while the actual application path called `wif_evaluate_direction`, so it did not fix the live behavior.

The deployed `20260915020000_presence_identity_and_freshness.sql` migration supersedes it: the active evaluator uses the state-aware city key and a 24-hour freshness gate, and `recompute_colocation_for_pair` delegates to that evaluator. Applying the older file now would overwrite that safe delegation with stale logic. Keep this SQL only as historical source; it must not be placed back in `supabase/migrations` or added to the hosted migration ledger.

Read-only hosted checks on September 23, 2026 confirmed that the old version was absent from the ledger, the replacement version was present, and the active function used the 24-hour rule. With the file retired, `supabase db push --linked --dry-run --skip-vault` reported the remote database was up to date.
