# NGO UI/UX Improvement Tracker

Date: 2026-04-14
Scope: NGO Flutter UI only (no backend/service/schema changes)

## Audit Findings

1. Tiny task action buttons in task cards
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: `AI Update`, `Edit`, and `Delete` controls use compact chips with small text/icons and low-height hit areas.
- Impact: Hard to tap reliably, especially on smaller devices.
- Priority: High
- Status: Implemented

2. Risky button hierarchy around destructive actions
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: Small adjacent actions sit close to destructive `Delete`, increasing mis-tap risk.
- Impact: Higher chance of accidental destructive action.
- Priority: High
- Status: Implemented

3. Global `AI Refactor` trigger is undersized
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: Header-level `AI Refactor` uses a tiny text button.
- Impact: Hard to discover/tap and visually under-prioritized.
- Priority: High
- Status: Implemented

4. Batch AI refactor sheet visual mismatch
- File: lib/components/ai_batch_task_sheet.dart
- Issue: Uses fixed indigo/purple styling that does not match app theme or single-item AI sheet.
- Impact: Inconsistent UX and trust drop between two AI flows.
- Priority: High
- Status: Implemented

5. Batch AI sheet submit/apply controls have small touch targets
- File: lib/components/ai_batch_task_sheet.dart
- Issue: Send and preview action controls are compact and dense.
- Impact: Input friction and accidental taps.
- Priority: High
- Status: Implemented

6. Destructive/primary actions are not clearly separated in batch preview
- File: lib/components/ai_batch_task_sheet.dart
- Issue: `Discard` and `Apply` are visually close and similarly sized.
- Impact: Error-prone final confirmation step.
- Priority: Medium
- Status: Implemented

7. Review extraction screen has weak primary/destructive hierarchy
- File: lib/pages/review_detail_screen.dart
- Issue: Tiny top-right AI icon-only action and low-emphasis discard action placement near primary workflow.
- Impact: Lower discoverability and occasional accidental cancellation.
- Priority: Medium
- Status: Implemented

8. Proof review footer uses asymmetric action sizing
- File: lib/pages/proof_detail_screen.dart
- Issue: Big primary approve button with a compact red reject icon-only button.
- Impact: Reject action is less legible and harder to tap intentionally.
- Priority: Medium
- Status: Implemented

9. Task editor skill chips are visually/tactically small
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: Skill chips use very small label text and tight spacing.
- Impact: Hard to scan and toggle quickly on smaller devices.
- Priority: Medium
- Status: Implemented

10. Custom tag add control is icon-only and tiny
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: Custom tag add action uses a compact icon button next to text field.
- Impact: Low discoverability and higher mistap probability.
- Priority: Medium
- Status: Implemented

11. Task details header action overflows on narrow widths
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: "AI Refactor Tasks" button overflows in the same row as section title.
- Impact: Visual breakage and clipped controls on phones.
- Priority: High
- Status: Implemented

12. Review card "AI DRAFT" affordance is redundant noise
- File: lib/pages/review_queue_screen.dart
- Issue: "AI DRAFT" marker suggests an action but card tap already opens review.
- Impact: Cognitive clutter without extra utility.
- Priority: Medium
- Status: Implemented

13. Review discard button text clipping under compact/layout scaling
- File: lib/pages/review_detail_screen.dart
- Issue: "Discard Extraction" label can clip/half-hide due control composition.
- Impact: Reduced clarity for critical cancellation path.
- Priority: High
- Status: Implemented

14. Active contributors should remain horizontally scrollable at higher member counts
- File: lib/components/volunteer_team_list.dart
- Issue: Need explicit horizontal scrolling affordance for crowded contributor lists.
- Impact: Hidden contributors on small screens if not clearly scrollable.
- Priority: High
- Status: Implemented

15. Coordination Chat button needs centered, wider row treatment
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: Chat CTA should dominate a dedicated row for quick access.
- Impact: Inconsistent hierarchy with surrounding controls.
- Priority: High
- Status: Implemented

16. AI Update and Edit Task need equal width in a centered row
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: Dual primary actions should share equal visual weight.
- Impact: Better scanability and action predictability.
- Priority: High
- Status: Implemented

17. Delete Task needs its own final row matching chat-row width
- File: lib/pages/ngo_task_detail_screen.dart
- Issue: Destructive action should sit in isolated row with same row width as chat CTA.
- Impact: Safer and more deliberate destructive interaction.
- Priority: High
- Status: Implemented

18. Approve action in review detail should not block on backend matching latency
- File: lib/pages/review_detail_screen.dart
- Issue: Approve keeps user in loading state while waiting for downstream task generation.
- Impact: Feels stuck and adds manual back-navigation burden.
- Priority: High
- Status: Implemented

## Implementation Checklist

- [x] Enlarge and re-layout task action controls in NGO task cards.
- [x] Replace tiny `AI Refactor` text control with larger accessible action.
- [x] Align batch AI sheet visuals with `AiAssistantSheet` theme-driven style.
- [x] Increase touch targets in batch AI input and preview action rows.
- [x] Improve destructive action spacing/hierarchy in task and proof review contexts.
- [x] Keep all changes UI-only and verify no backend/service behavior changes.
- [x] Increase task editor chip readability and hit area.
- [x] Replace icon-only custom-tag add action with labeled control.
- [x] Make task section action row responsive to phone widths.
- [x] Remove redundant "AI DRAFT" visual noise from review cards.
- [x] Rework discard extraction control to avoid text clipping.
- [x] Keep active contributors horizontally scrollable with clear affordance.
- [x] Center coordination chat CTA at 75% row width.
- [x] Make AI Update and Edit Task equal-width in one centered row.
- [x] Make Delete Task occupy dedicated final row at chat-row width.
- [x] Show approval snackbar and redirect immediately to NGO dashboard.

## Notes

- This tracker is the source of truth for this pass.
- If additional issues are discovered during implementation, append them here first.
