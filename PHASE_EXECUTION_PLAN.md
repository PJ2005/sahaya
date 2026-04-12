# Phase Execution Plan (Source of Truth)

Date started: 2026-04-12

Use this doc as master phase context. Chat can be short. Work reference comes from here.

## Rules

1. Implement one phase at a time.
2. After each phase: list changed files + UI/backend check steps.
3. Next phase starts only after user approval.

## Phases

### Phase 1: Security hardening
Status: Completed

Scope:
- Tighten Firestore authorization
- Add backend ownership/idempotency/input checks

Implemented in:
- `firestore.rules`
- `services/telegram-webhook/app.py`

### Phase 2: Data quality and fraud guardrails
Status: Completed

Scope:
- Upload fingerprints
- Duplicate problem-card detection
- Quality flags and anomaly events

Implemented in:
- `services/telegram-webhook/app.py`

### Phase 3: Matching constraints + explainability
Status: Completed

Scope:
- Add constraint filters (language/trust/safety)
- Add richer match explanation payload
- Show explanation better in volunteer UI

Planned files:
- `services/telegram-webhook/app.py`
- `lib/pages/volunteer/task_details_screen.dart`

Implemented:
- Added language/trust/safety constraint filters in matching engine.
- Added richer match explain payload (`whyMatched`, `explainFactors`, filter metadata).
- Updated volunteer task detail explanation to prefer backend generated `whyMatched` and richer fallback.

### Phase 4: Dynamic re-dispatch and route baseline
Status: Completed

Scope:
- Auto detect stale accepted assignments
- Redispatch tasks to fresh volunteers
- Add baseline travel-time estimate for prioritization

Tasks:
- Add backend redispatch function to expire stale accepted match records.
- Add endpoint `POST /redispatch-task` for manual task redispatch.
- Add endpoint `POST /redispatch-cycle` for batch redispatch.
- Add scheduler job to run redispatch cycle every 30 minutes.
- Extend match payload with `estimatedTravelMinutes` and redispatch metadata.

Implemented in:
- `services/telegram-webhook/app.py`

### Phase 5: Offline conflict sync v1
Status: Completed

Scope:
- Expand offline queue beyond proof upload
- Add deterministic conflict policy and merge metadata

Tasks:
- Add queued action model for task status/note updates.
- Add conflict resolver policy (`server_wins` + local merge note).
- Write conflict events to Firestore for admin review.
- Add retry budget and dead-letter queue for failed sync actions.

Planned files:
- `lib/services/offline_proof_sync_service.dart`
- `lib/pages/volunteer/active_task_screen.dart`
- `services/telegram-webhook/app.py`

Implemented:
- Upgraded offline queue to action model v2 (`proof_submit`, `task_update`).
- Added retry budget and dead-letter queue in local storage.
- Added backend endpoint `POST /sync-task-update` with `server_wins` conflict policy.
- Added conflict logging to Firestore (`sync_conflicts`) and quality events.
- Wired offline proof flow to enqueue task-update replay metadata.

### Phase 6: Command center upgrades
Status: Completed

Scope:
- Better NGO operational visibility and actionability

Tasks:
- Add incident queue widget and drill-down panels.
- Add SDG tag mapping for problems/tasks.
- Add KPI drill-through from chart to concrete task/match list.
- Add redispatch action button from NGO views.

Planned files:
- `lib/pages/ngo_impact_dashboard_screen.dart`
- `lib/pages/ngo_home_screen.dart`
- `lib/pages/ngo_dashboard.dart`

Implemented:
- Added incident queue card in impact dashboard for stale accepted assignments.
- Added Redispatch action button per incident item, wired to backend redispatch endpoint.
- Added SDG tag mapping and display in NGO home problem cards.
- Added KPI drill-down interactions via tap on KPI cards.

### Phase 7: Accessibility and multilingual base
Status: Completed

Scope:
- Add foundation for localization and accessibility

Tasks:
- Wire Flutter localization delegates and supported locales.
- Add starter localized strings (English + Tamil).
- Add semantics labels for key action controls.
- Add high-contrast style toggle baseline.

Planned files:
- `lib/app.dart`
- `lib/main.dart`
- `lib/pages/volunteer/volunteer_home_screen.dart`
- `lib/pages/ngo_home_screen.dart`
- `pubspec.yaml`

Implemented:
- Added lightweight EN/TA localization delegate and string map (`lib/l10n/app_text.dart`).
- Added global locale provider and language toggle controls in NGO/Volunteer home app bars.
- Wired `supportedLocales` and `localizationsDelegates` in `MaterialApp`.
- Added high-contrast baseline toggle through `ThemeProvider` and `SahayaTheme` variants.
- Added semantics/tooltips for core app-bar controls and NGO FAB action.

### Phase 8: Scenario simulator MVP
Status: Completed

Scope:
- What-if planning tool for NGO ops

Tasks:
- Add backend simulation endpoint for shortage/surge scenarios.
- Add impact projection math for coverage and expected delay.
- Add simple NGO simulator panel UI with input sliders.
- Save scenario runs to Firestore for comparison history.

Planned files:
- `services/telegram-webhook/app.py`
- `lib/pages/ngo_impact_dashboard_screen.dart`

Implemented:
- Added backend endpoint `POST /simulate-scenario` with shortage/surge/horizon inputs.
- Added projection outputs for coverage, backlog slots, delay hours, and risk level.
- Persisted each simulation run in Firestore collection `scenario_runs`.
- Added NGO impact dashboard simulator card with sliders, run action, and inline result summary.
