# Feature Gap Audit (Google Solution Challenge 2026)

Date: 2026-04-12

Scope reviewed:
- Flutter app under `lib/`
- Backend service under `services/telegram-webhook/`
- Security rules in `firestore.rules`
- Tests and project metadata where relevant

This audit checks what is still missing from the previously recommended 10 "winning" features.

## Summary

1. Fully missing features: 5
2. Partially implemented but incomplete: 5
3. Fully implemented from the list: 0

## Detailed Gaps By Feature

### 1) AI Survey Digitization Pipeline (Photo + OCR + NLP)
Status: Partially implemented

What exists:
- OCR/text extraction for PDF, CSV, TXT, Excel, image OCR via ML Kit in `lib/services/extraction_service.dart`.
- Gemini extraction endpoint in `services/telegram-webhook/app.py` (`/api/gemini/extract-problems`).

What is missing:
- No confidence-calibrated extraction quality layer (field-level confidence validation and rejection thresholds).
- No multilingual OCR/NLP pipeline design (current OCR uses Latin script recognition only).
- No document-level deduplication for repeated survey intake across sources.
- No human-in-the-loop correction queue specifically for OCR/NLP parse errors.

### 2) Urgency & Vulnerability Scoring Engine
Status: Partially implemented

What exists:
- Priority score computation with severity/scale/recency/gap in `services/telegram-webhook/app.py` (`/generate-tasks`).

What is missing:
- No explicit vulnerability dimensions (children, elderly, disability, chronic disease, socioeconomic risk).
- No dynamic decay/refresh model after interventions or changing field conditions.
- No transparent policy versioning for scoring weights over time.
- No measurable calibration pipeline to validate that score ranks true urgency.

### 3) Smart Volunteer-Task Matching with Explainability
Status: Partially implemented

What exists:
- Matching based on skill overlap, distance, and availability in `services/telegram-webhook/app.py` (`_run_matching_internal`).
- Basic user-facing explanation in `lib/pages/volunteer/task_details_screen.dart`.

What is missing:
- No hard constraints for language matching, safety/risk suitability, certifications, or trust-level gating.
- No fairness/diversity controls in ranking.
- No feedback loop that learns from accepted/rejected assignments.
- Explanations are surface-level and not tied to weighted feature contribution values shown to NGO admins.

### 4) Dynamic Dispatch & Route Optimization
Status: Missing

What exists:
- Static one-time matching when tasks are generated.

What is missing:
- No live re-dispatch engine when volunteer drops, conditions change, or new urgent tasks arrive.
- No route optimization/ETA computation.
- No batching optimization for multi-task volunteer trips.
- No event-driven reassignment workflow.

### 5) Offline-First Field App + Conflict Sync
Status: Partially implemented

What exists:
- Offline queue and later sync for proof submission in `lib/services/offline_proof_sync_service.dart`.
- Connectivity awareness in app wrappers/screens.

What is missing:
- Offline-first support is narrow (proofs), not end-to-end for full field workflows (task updates, form edits, dispatch changes).
- No explicit conflict resolution strategy for concurrent edits (merge policy, priority, resolver UI).
- No durable retry telemetry/observability for failed sync jobs.

### 6) Impact Command Center (Live Heatmaps + KPIs)
Status: Partially implemented

What exists:
- KPI dashboard in `lib/pages/ngo_impact_dashboard_screen.dart`.
- Heatmap view in `lib/pages/ngo_heatmap_screen.dart`.

What is missing:
- No true real-time operations command center with incident queue + dispatch controls in one place.
- No SDG-aligned impact mapping and reporting.
- No drill-down from KPI to intervention-level decision actions.
- Some data loading paths are constrained (for example, where-in limited subsets), which can underrepresent full NGO data at scale.

### 7) Abuse/Fraud & Data Quality Guardrails
Status: Missing

What exists:
- AI proof verification for submitted photos in backend.

What is missing:
- No duplicate survey/report detection.
- No anomaly detection for suspicious volunteer/task/proof behavior.
- No anti-gaming controls for trust score inflation.
- No data-quality scoring pipeline (completeness, consistency, plausibility checks) before records drive priority/matching.

### 8) Privacy-by-Design Layer
Status: Partially implemented

What exists:
- Authentication and collection-level security rules in `firestore.rules`.
- Basic anonymized field usage in problem-card flows.

What is missing:
- No formal consent capture and consent revocation tracking.
- No audit trail for sensitive data access and admin actions.
- No explicit data retention/deletion policy automation.
- No field-level encryption/tokenization strategy for high-risk PII.
- Firestore rules are broad for some collections (example: `tasks` currently allows read/update/create/delete for any authenticated user).

### 9) Inclusive UX: Multilingual + Voice + Accessibility
Status: Partially implemented

What exists:
- Voice input/recording flows in some forms.
- Language preference field in volunteer profile model.

What is missing:
- No localization framework wiring (`supportedLocales`, delegates, ARB workflow) across UI.
- No explicit accessibility semantics support (screen reader labels, focus hints, announced states).
- No high-contrast accessibility mode and no accessibility conformance checks documented.
- No low-literacy UX flow set (icon-first guided actions, assisted confirmation patterns) beyond basic voice capture.

### 10) What-If Scenario Simulator
Status: Missing

What exists:
- None found in app/backend for predictive scenario simulation.

What is missing:
- No simulation engine for volunteer shortage, weather/disaster spikes, or incident surges.
- No policy experimentation tools to compare allocation outcomes.
- No forecasted impact projections for pre-event planning.

## Priority Build Order (for maximum judging impact)

1. Dynamic dispatch + route optimization (Feature 4)
2. Fraud/data-quality guardrails (Feature 7)
3. Privacy-by-design hardening (Feature 8)
4. Full offline-first + conflict sync (Feature 5)
5. Inclusive UX localization/accessibility package (Feature 9)
6. Scenario simulator MVP (Feature 10)

## Notes

- This audit distinguishes "exists in some form" vs "implemented to competition-winning depth".
- Several core foundations are strong already (OCR, extraction, matching, KPI visualization), but the missing layers above are the biggest differentiators for Technical Merit, Innovation, and Cause Alignment scoring.