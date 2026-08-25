# Floor Schedule — Southern Spreaders

A factory floor production scheduling tool: sequences builds across shop tasks against daily
labour-pool capacity, tracks real clock-in/out time per sub-task, and reports on both
scheduling and job profitability.

This file is the orientation map for anyone (human or AI) picking this project up cold —
architecture, where things live, and how to make a change safely. See `CHANGELOG.md` for what's
been built and why, in roughly chronological order.

## Architecture in one paragraph

The entire application is one self-contained file, `index.html` (~8,000 lines: markup, CSS, and
a single `<script>` IIFE — no build step, no bundler, no framework). It's deployed by pushing to
GitHub, which Vercel auto-redeploys as a static site. Data is stored as one JSON blob in
`localStorage` (instant, offline-safe reads) and mirrored to a Supabase Postgres table
(`app_state`) for cross-device sync — see "Data & sync" below. There is deliberately no
server-side logic beyond Supabase Auth and RLS policies.

## Repo layout

- `index.html` — the whole app.
- `supabase-auth-setup.sql` — the SQL to run (once, in the Supabase SQL editor) to stand up
  `app_state` RLS, the `profiles` table (login roles), and any later migrations appended to the
  bottom of the file. **Run new sections of this file manually against the live Supabase project
  when a change adds one** — it is not applied automatically.
- `README.md` — this file.
- `CHANGELOG.md` — feature history.

## Data model (the big pieces)

Everything lives in one `state` object, persisted as a single JSON blob. The major top-level
keys:

- `state.tasks` — the shop's task sequence (MS, SS, Blast, Paint, …), each with a labour `poolId`
  (and optional `secondaryPoolId`), and a `sharedClock` flag (Blast/Paint-style tasks where two
  people can clock onto the same task at once, time split by real overlap).
- `state.pools` — labour pools with weekday hour capacity plus date-ranged overrides.
- `state.builds` — the actual schedule: one entry per machine being built, each with an
  `orderDate`/`leadDays` (when it's allowed to start) and hours-per-task. Priority is simply
  array order (drag-reorderable in Schedule & Builds). A build is linked to its data either via
  `jobRecordId` (a Jobs-tab job — the current, fully-featured path) or the older `templateId`
  (flat machine templates, no sub-task tree).
- `state.jobRecords` — Jobs-tab jobs: `{ tasks: [{ taskRefId, subtasks: [...] }] }`. Each
  sub-task (`{ number, name, standardTime, selected, timeLogs, completed, … }`) is real,
  loggable work — `standardTime` sums up into the task's planned hours, and `timeLogs` holds
  every real clock-in/out. **A sub-task's `number` is a real sort key, not just a label** —
  `normalizeState()` re-sorts every task's sub-tasks by number on every load, because that array
  order is exactly what the scheduler and the employee's daily checklist window walk to decide
  what's due which day.
- `state.jobTemplates` — the reusable T11/T15/TFS4-style library a job's task tree is cloned
  from at creation time (never re-synced afterward).
- `state.optionTemplates` — reusable add-ons (see "Options" below).
- `state.people` / `state.adHocCards` / `state.actuals` / `state.dayFinished` — labour pool
  roster, ad-hoc work (Lost Time/Rework/Supervision/Factory Maintenance), manager-confirmed
  sign-off hours per (date, build, task), and the floor's own "day finished" lock.
- `state.financialReports` — saved profit reports (see "Financial Reports" below).

The **scheduling engine** is `runSchedule()` — a deterministic day-by-day greedy simulation
(builds in priority order, each competing for pool capacity), fully documented at its own
comment block. It is pure with respect to `state.builds` (never mutates it), which is what lets
`previewBuildMove()` temporarily reorder builds, re-run the exact same engine, and diff the
result — nothing else in the app needs special-casing for "what-if" previews.

### Options

A reusable add-on (`state.optionTemplates`) defines items — `{ taskId, subtaskName, hours }` —
that get injected as ordinary tagged sub-tasks (`fromOptionId`/`fromOptionName`) onto a job when
applied. Hours flow into scheduling for free, since they're just normal sub-tasks. Cost of goods
for an option is deliberately **not** stored on the job or the option — it's entered per
(option, task) only when a Financial Report is generated (`report.costOfGoodsByOption`), same as
a regular task's cost of goods. Options can be restricted to specific machine types via
`applicableMachineTypes` (empty = applies everywhere).

### Financial Reports

`financialReportBreakdown(report)` is the one function that turns a saved report's dollar inputs
(hourly rate, sell price, cost of goods) plus live schedule/sign-off data into a profit
breakdown — hours are always read live off current state (never frozen at report-creation time),
so an in-progress job's report keeps catching up as real work gets logged. It separately tracks
base-task figures and option figures (splitting a task's hours between "normal" and
"came from an option" using the tagged sub-tasks), and computes both planned and actual net
profit so a manager can see budget-vs-reality at a glance.

## Login roles

Supabase Auth + a `profiles` table (`role` + `person_id`). `applyRoleUI()` is the single place
that gates the UI:

- **manager** — full access.
- **floor** — only the Job Cards page, and only their own linked person's card, with most
  incidental detail (name, hours totals, date navigation, sub-task numbers, other people's
  session history) deliberately stripped out. New floor-only page/detail restrictions should be
  added here, not scattered elsewhere.
- **sales** — Schedule & Builds and Stock only.

Adding a new role means: widen the `profiles.role` check constraint in Supabase (see
`supabase-auth-setup.sql`), add a branch in `applyRoleUI()`, and add it to the role picker in the
Logins page.

## Making a change safely

There's no automated test suite — a real browser pass before every push is the only quality
gate, and it's worth keeping that discipline:

1. Temporarily add two debug hooks right after `boot()` closes:
   ```js
   window.__forceReload = () => { state = load(); normalizeState(); save(); renderAll(); return state.people.length; };
   window.__testRole = (role) => {
     currentSession = { user: { id: 'test' } };
     document.getElementById('appShell').style.display = '';
     document.getElementById('authGate').style.display = 'none';
     currentProfile = { role, person_id: state.people[0] && state.people[0].id };
     applyRoleUI(); renderAll();
   };
   ```
2. Open the file in the Claude_Browser sandbox (`file:///…/index.html`), call
   `window.__forceReload(); window.__testRole('manager')` (or `'floor'`/`'sales'`) via
   `javascript_exec`, and drive the UI directly through DOM queries — this bypasses needing a
   real Supabase login while testing against real local data.
3. **Always remove both hooks before committing** — grep the diff for `__forceReload`/
   `__testRole` before every push.
4. Check the browser console for errors after each significant interaction.
5. `git add index.html && git commit && git push` — Vercel redeploys automatically.

Known environment quirk: `navigate()` in the sandbox browser doesn't always give a fresh JS
context on reload — `window.__forceReload()` is the reliable way to force `state` to actually
re-read from `localStorage` after a data change made outside the running page.

## Data safety

There is no automated backup. The Export config button (manager toolbar) writes the whole
`state` blob to a JSON file — worth doing periodically, and definitely before any risky change
(a Supabase schema migration, a bulk data edit). Supabase itself also has point-in-time recovery
on paid tiers; check the current plan if that matters.
