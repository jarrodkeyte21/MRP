# Changelog

Feature history for the Floor Schedule app, newest first. This is a human-readable summary —
see `git log` for exact commits, and `README.md` for how the pieces fit together.

## Options

- Sub-task numbering added to option items, with auto-reorder: editing a number now actually
  re-sorts the task's real sub-task array (numeric-aware), and `normalizeState()` re-sorts on
  every load so the order holds regardless of how sub-tasks got there.
- Options can be restricted to specific machine types (checkboxes in the library); a job's
  "pick an option" list only offers options that apply to it.
- Collapsed option task rows show sub-task count and hours together.
- Cost of goods moved out of the option/job entirely — now entered only per (option, task) when
  generating a Financial Report.
- A one-off custom option can be built directly on a job without saving it to the library.
- An applied option's sub-tasks are editable per job (hours, name, add/remove) without touching
  the shared template — grouped and collapsed by task, matching the job's own Tasks table.
- CSV import/export for an option's items.
- Fixed a bug where typing in an option's fields re-rendered the whole page and reset scroll
  position.
- Initial feature: reusable add-ons that inject tagged sub-tasks (hours) into a job's tasks —
  library lives on the Jobs tab.

## Financial Reports

- New manager-only tab: generate a profit report against any scheduled job (hourly rate, sell
  price, cost of goods per task), reports stay saved and expandable.
- Hours (planned vs actual, with variance) are read live off the schedule/sign-off history, not
  frozen at report creation.
- Gross profit (revenue − cost of goods) and net profit (also − labour) computed for both
  planned and actual hours, with margin percentages.
- Per-task and per-option totals shown as a footer row under their own columns rather than
  restated in a separate summary block.
- Business Performance section: totals across every report, gross-vs-net and planned-vs-actual
  bar charts per job, and the same grouped by machine type.

## Scheduling

- "Preview a move" panel on Schedule & Builds: pick a job, choose where to move it in priority,
  and see which other jobs' finish dates shift — and optionally simulate letting it jump the
  queue on overtime instead — before committing anything.
- The job cards date view now auto-advances at midnight if a browser tab is left open, instead
  of getting stuck on yesterday.

## Login roles

- Added a Sales role (Schedule & Builds and Stock only).
- Floor login progressively locked down to just their own Job Card: no page header/branding, no
  date picker (always today), no name or hours-selected totals shown, no sub-task numbers, no
  reassigning a session to someone else, no visibility into other days' session history, and no
  starting/stopping/adding time once the day is marked finished (with a confirm step either way).
- Rework logged against a job already on the card folds into that job's own card instead of
  showing as a separate panel.

## Job card (employee-facing) redesign

- Rebuilt as stacked touch-friendly cards (was a dense table) for iPad use: big colour-coded
  Start/Stop and Mark complete buttons, sessions tucked behind a toggle, "Add work to this card"
  collapsed by default.
- Heading simplified to job # / machine type / dealer-customer (dropped status/total-hours),
  enlarged, with Rework moved next to it.
- A sub-task can be picked directly in "Add work to this card" so hours go straight onto the
  real sub-task even if it wasn't scheduled.

## Supervision / Factory Maintenance / labour tracking

- Supervisors get a dedicated Start/Stop control (with job picker) pinned to their card.
- Factory Maintenance / Lost Time: a single evergreen job every card can clock onto, reporting
  resets monthly.
- Shared-clock tasks (Blast/Paint) let two people clock on at once, with real overlap-based time
  splitting instead of a flat 50/50.
- Delete + editable notes on all ad-hoc-style entries (Lost Time, Rework, Supervision, Factory
  Maintenance).

## Foundation

- Initial build: capacity-constrained scheduling engine, Job Card Setup/Job Cards/Reports/Stock/
  Job History pages, Setup (task sequence + labour pools).
- Live sync via Supabase (`app_state` table, RLS tightened to authenticated users only).
- Login system with manager/floor roles via Supabase Auth + a `profiles` table.
