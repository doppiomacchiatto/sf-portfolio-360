# Portfolio Manager — R&D Framework

Salesforce DX project for the R&D Portfolio Manager application, tracking all 14 KPIs across investment, speed, technical maturity, portfolio health, transition, and operational outcomes.

## Deployment Checklist

Use this order for sandbox/demo deployments:

1. Create/install unmanaged package metadata (`force-app`) and assign permission sets.
2. Deploy Experience site metadata (`experiences/`).
3. Load demo data using scripts.
4. Publish the Experience site in Experience Builder.

### Quick Commands

```bash
# 1) Package + permission sets
./scripts/deploy-package-and-permsets.sh -o <alias> -u <exec-user> -p PM_Executive,PM_Admin

# 2) Experience metadata
./scripts/deploy-experience.sh <alias>

# 3) Data load
./scripts/load-seed-data.sh <alias>
./scripts/load-saturn-data.sh <alias>
```

> Important: after deploying Experience metadata, open Experience Builder and click Publish before validating site behavior.

## Build Tasks

### Foundation
- [x] Custom Objects — Program__c, TRL__c, MRL__c, Technical_Exam__c, Evidence__c, User_Partner_Engagement__c, Project_Transition__c
- [x] Custom Fields — all KPI-mapped fields including formula fields (TRL_Gain, MRL_Gain, Pass_Rate, Days_to_Decision, Transition_Commitment_Complete, Is_Transitioned)
- [x] Custom Tabs — all 7 objects
- [x] Lightning Applications — Portfolio Manager, PM Executive
- [x] FlexiPage shell — PM_Executive_Home (AppPage, defaultAppHomeTemplate)

### Navigation & UI
- [x] Assign PM_Executive_Home as the home page for the PM Executive app (Lightning App Builder → Activate)
- [x] Page Layouts — one per custom object (Program, TRL, MRL, Exam, Evidence, UPE, Transition)
- [x] Compact Layouts — for each object (shown in related lists and mobile)
- [x] Lightning Record Pages — Program__c record page (highlights panel, detail, related lists, chatter feed)
- [x] List Views — default "All" + filtered views per object (Active Programs, Critical TRL, High Supply Chain Risk, Pending Decision, Open/Completed Transitions)

### Security
- [x] Permission Set: `PM_Analyst` — read/write on all custom objects, Portfolio Manager app
- [x] Permission Set: `PM_Executive` — read-only (viewAll) on all custom objects, PM Executive app
- [x] Permission Set: `PM_Admin` — full CRUD + delete + modifyAll on all custom objects, both apps

#### PM Executive Permission Set Notes
- `PM_Executive` is the required permission set for executive app and LWR experience users.
- The permission set includes read access for executive KPI objects and related standard objects used in dashboard context (`Case`, `Task`).
- `PmDashboardController` Apex Class Access is required for LWC data wires in the executive experience site.
- If the site shows `The Apex request is invalid.`, validate that the user has:
  - `PM_Executive` assigned
  - Apex class access to `PmDashboardController`
  - active login session after a hard refresh/logout-login

#### Experience Cloud — External Sharing Model

Experience Cloud members use the **external** OWD (Organization-Wide Default), which is separate from the internal sharing model. Custom objects without an explicit `externalSharingModel` default to **Private** for community members, blocking all record access even when the internal OWD is Public.

`Program__c` is set to:
```xml
<externalSharingModel>ReadWrite</externalSharingModel>
<sharingModel>ReadWrite</sharingModel>
```

All six child objects (`TRL__c`, `MRL__c`, `Technical_Exam__c`, `Evidence__c`, `User_Partner_Engagement__c`, `Project_Transition__c`) are **master-detail** children of `Program__c`. Their external sharing is automatically controlled by the parent — no separate `externalSharingModel` is needed on them.

If Experience Cloud members see an error page when navigating to a Program record, verify `externalSharingModel` is set on `Program__c` and the change has been deployed.

#### Experience Cloud — Internal User Access (No Login Redirect)

Internal Salesforce users are redirected to the site's login page if their profile or permission set is not listed in `networkMemberGroups`. This applies even to System Administrators and VRM Administrators — if the Network metadata doesn't include their profile, they hit a login wall.

The required `networkMemberGroups` in `experiences/main/default/networks/titanx.network-meta.xml`:

```xml
<networkMemberGroups>
    <permissionSet>PM_Executive</permissionSet>
    <permissionSet>PM_Analyst</permissionSet>
    <permissionSet>PM_Admin</permissionSet>
    <profile>admin</profile>
    <profile>vrm administrator</profile>
</networkMemberGroups>
```

`profile: admin` = System Administrator. `profile: vrm administrator` = VRM Administrator (the org's custom admin profile). Both must be present or those users get redirected to login.

**Deploy note:** Redeploy `experiences/` after any change to `networkMemberGroups`. Changes do not take effect until deployed and the site is published.

#### Experience Cloud — Object Renames Break digitalExperiences/* References

Renaming a custom object's API name (e.g. `Program__c` → `pm_Program__c`) is **not** caught by a search/replace across `force-app/` alone. The Digital Experience site (`experiences/main/default/digitalExperiences/titan1/`) embeds object API names as plain string values inside route and view JSON, not as typed metadata references:

- `sfdc_cms__route/<Name>/content.json` → `routeType` (e.g. `"detail-Program__c"`, `"list-Program__c"`, `"relatedlist-Program__c"`)
- `sfdc_cms__view/<Name>/content.json` → `viewType` (same pattern)

If these aren't updated to match the renamed object, deploying `experiences/` fails with:
```
No custom object exists in the Org with given ObjectAPIName: Program__c. Please update the routeType or install the required CustomObject.
```

**Whenever you rename/refactor a custom object, grep `experiences/` for the old API name and update every `routeType`/`viewType` hit before redeploying:**
```bash
rg "Program__c" experiences/
```

#### Experience Cloud — Cross-Domain Re-Login (Workspaces / Setup)

Even with `networkMemberGroups` configured correctly, internal users can still be forced to log in again when they navigate from the site domain (`*.my.site.com`) to an internal Salesforce domain — for example, clicking through to Digital Experience Workspaces (Builder/Administration) from the live site. This is a separate, org-wide setting, not a Network/site setting.

The cause is `lockSessionsToDomain` in Security Settings (Setup → Session Settings → **Lock sessions to the domain in which they were first used**):

```xml
<!-- force-app/main/default/settings/Security.settings-meta.xml -->
<sessionSettings>
    <lockSessionsToDomain>true</lockSessionsToDomain>
</sessionSettings>
```

With this enabled, a session issued on the site domain isn't honored on the internal Lightning/Setup domain (and vice versa), so crossing domains forces a fresh login even for an already-authenticated admin.

**Fix:** set `lockSessionsToDomain` to `false` and redeploy `Settings:Security`.

> **Trade-off:** this setting is org-wide — it relaxes cross-domain session locking for the entire org, not just the `titanx` site. It's a standard mitigation for session hijacking; disabling it is a common but deliberate trade-off for Experience Cloud/internal-user UX.

#### Experience Cloud — Workspaces Identity Verification (Browser/Device Trust)

The first time you access Digital Experience Workspaces (Administration/Builder) from a **browser or device Salesforce hasn't seen before**, you may be forced through a full identity verification challenge — username/password plus MFA — even though you're already an authenticated internal admin with `networkMemberGroups` and `lockSessionsToDomain` configured correctly. This is **not** a site or Network configuration issue. It's this org's mandatory MFA policy applying a one-time step-up check to a new browser/device.

What we observed while diagnosing this on `titanx`:

- The redirect (`/titanx/login?ec=302&...`) leads to a real Salesforce login form, then an MFA "Verify Your Identity" challenge.
- WebAuthn credentials (security keys, passkeys, platform "Built-In Authenticator") are scoped to the **domain they were registered on**. A key registered via Setup on the internal org domain (`*.my.salesforce.com`) will not satisfy a challenge on the site domain (`*.my.site.com`), and vice versa — expect a "security key not registered with this site" error if you cross domains.
- Some browsers (e.g. Vivaldi) have gaps in WebAuthn platform-authenticator support (Windows Hello/Touch ID) even though they're Chromium-based; a listed "Built-In Authenticator" may be unresponsive there. Prefer Chrome/Edge, or use a hardware security key (YubiKey, etc.) — hardware keys use standard USB/CTAP2 and work consistently across browsers.
- Once **any** verification method succeeds in a given browser, that browser is remembered/trusted going forward — subsequent access (including to other, unrelated sites/networks in the same org) no longer triggers the challenge. This is why the issue can appear to "fix itself" or seem inconsistent between two sites in the same org.

**If you get stuck with no working verification method:** fall back to an Email or SMS verification code (Setup → Advanced User Details), or register a new Security Key while already authenticated, then retry.

#### Data Load — FLS Note

The data load scripts (`load-seed-data.sh`, `load-saturn-data.sh`) require the running user to have `PM_Admin` assigned in addition to `PM_Executive`. `PM_Admin` grants write access to all fields including `Fund_Allocation__c`, which is not writable via `PM_Executive` alone.

```bash
sf org assign permset --name PM_Admin --target-org <alias>
sf org assign permset --name PM_Executive --target-org <alias>
```

### Data Quality
- [x] Validation Rules — TRL/MRL current range 1–9, previous range 1–9 (when set), exam pass ≤ administered, exam pass ≥ 0, administered > 0, decision date after evidence date, timeline ordering (prototype after award, demo after prototype)
- [x] Required field review — Assessment_Date, Current_TRL/MRL, Technology_Element, Manufacturing_Capability enforced at field level; ranges enforced by validation rules

### Analytics
- [x] Report Types — custom report types joining Program__c to each child object
- [x] Reports — one per KPI group: Investment, Speed, Technical Maturity, Portfolio Health, Transition, Operational Index (14 KPIs total)
- [x] Report Folder — "PM KPI Reports"
- [x] Dashboards — PM Executive dashboard wiring all 14 KPIs to report components
- [x] Dashboard Folder — "PM Executive Dashboards"
- [x] Assign dashboard to PM_Executive_Home FlexiPage

| Report | KPI(s) | Report Type | Grouped By |
|---|---|---|---|
| `Portfolio_by_Fund_Allocation` | #1 | Programs | Program Status |
| `Portfolio_Balance_Mix` | #2 | Programs | Program Status |
| `Program_Speed_Metrics` | #3–5 | Programs | Program Status |
| `TRL_Assessments_by_Program` | #6 | Programs with TRL Assessments | Current TRL Level |
| `Technical_Exam_Results` | #8 | Programs with Technical Exams | Exam Type |
| `Evidence_Decisions` | #9 | Programs with Evidence Records | Program Status |
| `Transition_Pipeline` | #11–13 | Programs with Project Transitions | Program Status |

### Automation
- [x] Flow: Auto-update Program_Status__c to Transitioning when TRL >= 7 (Update_Program_Status_from_TRL)
- [x] Flow: Email alert to Program owner when Transition_Commitment_Complete__c flips to true (Transition_Commitment_Alert)
- [x] Roll-Up Summary Field: Engagement_Count__c on Program__c — COUNT of User_Partner_Engagement__c records

| Component | Type | What it does |
|---|---|---|
| `Update_Program_Status_from_TRL` | Flow | After Save on TRL__c — if Current_TRL__c ≥ 7, sets parent Program_Status__c = "Transitioning" |
| `Transition_Commitment_Alert` | Flow | After Update on Project_Transition__c — when Transition_Commitment_Complete__c flips to true, emails the Program owner |
| `Engagement_Count__c` | Roll-Up Summary Field | COUNT of User_Partner_Engagement__c records on Program__c |

### Advanced / LWC
- [x] LWC: KPI Scorecard (`pmKpiScorecard`) — grid of 14 live KPI metric tiles, grouped by Investment / Speed / Technical Maturity / Portfolio Health / Transition / Operational
- [x] LWC: Program Pipeline strip (`pmPipelineStrip`) — 5-phase chevron strip with live program counts per phase
- [x] LWC: KPI Tile (`pmKpiTile`) — reusable metric tile child component used by the scorecard
- [x] Apex: `PmDashboardController` — `getKpiData()` and `getPipelineData()` wire-cacheable methods

---

## Seed Data

| Object | Count | Notes |
|---|---|---|
| `Program__c` | 7 | One per pipeline stage — Ideation → Funded → Awarded → Prototype → Demo Complete → Transitioning → Operational |
| `TRL__c` | 14 | 1–3 assessments per program; CLARITY at TRL 8 (auto-set to Transitioning), VECTOR at TRL 9 |
| `MRL__c` | 11 | Paired with TRL where manufacturing readiness data applies |
| `Technical_Exam__c` | 7 | Mix of Midterm, Final, and Gate Review exams |
| `Evidence__c` | 8 | 2 Pivot decisions, 5 Continue; VECTOR evidence resolved |
| `User_Partner_Engagement__c` | 12 | User/Operator, Acquirer, Cyber/Mission Partner, Maintainer types |
| `Project_Transition__c` | 3 | APEX-7 (in progress), CLARITY (in progress), VECTOR (complete) |

### Programs

| Program | Status | Fund Allocation | Portfolio Balance |
|---|---|---|---|
| SIGMA-1 | Ideation | Validated | Disruptive/High Risk Bets |
| NEXUS-4 | Funded | Approved Critical Tech Area | Mission Pull |
| SHIELD-X | Awarded | Security-Gap | Near Term |
| FORGE | Prototype | Threat-Informed | Defense Unique Technology |
| APEX-7 | Demo Complete | Threat-Informed | Near Term |
| CLARITY | Transitioning | Security-Gap | Commercial Adoption |
| VECTOR | Operational | Validated | Near Term |

### Load Seed Data

```bash
./scripts/load-seed-data.sh [org-alias]   # default alias: tsx
```

---

## Saturn Moon Programs — Space Exploration Dataset

A second demo dataset of 7 programs named after Saturn's moons, each focused on cutting-edge / futuristic space exploration technology. Loaded independently; the existing 7 programs remain untouched.

| Object | Count | Notes |
|---|---|---|
| `Program__c` | 7 | Full pipeline coverage — Ideation → Funded → Awarded → Prototype → Demo Complete → Transitioning → Operational |
| `TRL__c` | 13 | 1–2 assessments per program; RHEA at TRL 8 (auto-set to Transitioning by flow), TITAN at TRL 9 |
| `MRL__c` | 11 | All programs from Funded onward; MIMAS has no MRL (pre-manufacturing) |
| `Technical_Exam__c` | 7 | Midterm, Gate Review, and Final exams across DIONE, IAPETUS, RHEA, TITAN |
| `Evidence__c` | 10 | 3 Pivot decisions (ENCELADUS, DIONE, IAPETUS) + 7 Continue; TITAN post-fielding outcome documented |
| `User_Partner_Engagement__c` | 15 | All four engagement types; 3 engagements each for DIONE, IAPETUS, RHEA, TITAN |
| `Project_Transition__c` | 3 | IAPETUS (not committed), RHEA (2/3 committed), TITAN (complete) |

### Programs

| Program | Status | Technology |
|---|---|---|
| MIMAS | Ideation | Gravitational Wave Navigation System — pulsar timing arrays for deep-space positioning without GPS |
| ENCELADUS | Funded | Zero-Point Energy Extraction Module — Casimir nano-cavity arrays harvest power from quantum vacuum |
| TETHYS | Awarded | In-Situ Nanofabrication Swarm — self-replicating nanobots mine regolith and 3D-print habitat structures |
| DIONE | Prototype | Cryogenic Suspended Animation Pod — 95% metabolic suppression for multi-year deep space crew transit |
| IAPETUS | Demo Complete | Photonic Light Sail Accelerator — phased laser array drives graphene sail toward 0.1c |
| RHEA | Transitioning | Quantum Entanglement Communication Array — zero-latency instantaneous deep-space telemetry |
| TITAN | Operational | Nuclear Fusion Micro-Thruster Array — 250 kN at 12,000 ISP; Mars transit in 39 days |

### Child Records

| Program | TRL | MRL | Exams | Evidence | UPE | Transition |
|---|---|---|---|---|---|---|
| MIMAS | 2 (TRL 2) | — | — | — | 1 | — |
| ENCELADUS | 3 (TRL 3) | 1 (MRL 2) | — | 1 Pivot | 1 | — |
| TETHYS | 5 (TRL 5) | 2 (MRL 4) | — | 1 Continue | 2 | — |
| DIONE | 6 (TRL 6) | 2 (MRL 5) | 1 Midterm | 2 (Pivot → Continue) | 3 | — |
| IAPETUS | 6 (TRL 6) | 2 (MRL 6) | 2 (Midterm + Gate) | 2 (Pivot → Continue) | 3 | Not committed |
| RHEA | 8 (TRL 8) | 2 (MRL 7) | 2 (Gate + Final) | 2 Continue | 3 | 2/3 committed |
| TITAN | 9 (TRL 9) | 2 (MRL 9) | 2 (Final + Gate) | 2 Continue | 2 | Complete |

### Load Saturn Data

```bash
./scripts/load-saturn-data.sh [org-alias]   # default alias: tsx
```

> RHEA lands as Transitioning automatically (TRL flow fires at TRL 8). TITAN lands as Operational after the script re-asserts it following the TRL 9 flow trigger.

### Wipe and Reload Saturn Data

```bash
./scripts/wipe-seed-data.sh [org-alias]          # wipes ALL records in the org
./scripts/load-seed-data.sh [org-alias]          # reload original 7 programs
./scripts/load-saturn-data.sh [org-alias]        # reload Saturn 7 programs
```

---

## Demo Script

### Demo Moment 1 — TRL Automation (Program Status Flow)

**What it shows:** Saving a new TRL record with a score ≥ 7 automatically flips the parent program's status to "Transitioning" — no code required.

1. Open **APEX-7** (currently "Demo Complete")
2. Go to the TRL Assessments related list → **New**
3. Set **Current TRL Level** = `7`, fill in Assessment Date and Technology Element
4. **Save**
5. Refresh the APEX-7 record — **Program Status is now "Transitioning"**

> The flow `Update_Program_Status_from_TRL` fires After Save on TRL__c when Current_TRL__c ≥ 7.

---

### Demo Moment 2 — Transition Commitment Alert (Email Flow)

**What it shows:** Completing all transition checklist fields on a project transition record automatically emails the program owner — the platform enforces the process.

1. Open **CLARITY** → Project Transitions related list → open the CLARITY transition record
2. Edit the record and check all three boxes:
   - **Signed Transition Agreement** → ✓
   - **Funded Receiver Path** → ✓
   - **Integration Plan** → ✓
3. **Save**
4. The `Transition_Commitment_Complete__c` formula evaluates to `true` (all criteria met)
5. The flow `Transition_Commitment_Alert` fires — **the program owner receives an email alert**

> To reset CLARITY for the next demo run, uncheck any one of the three boxes and save.

---

## Wipe and Reload

Run after each demo to restore the org to a clean seed state.

```bash
./scripts/wipe-seed-data.sh [org-alias]   # default alias: tsx
./scripts/load-seed-data.sh [org-alias]
```

The wipe script deletes children before parents to avoid FK constraint errors. The load script re-imports all records and re-asserts VECTOR's status to Operational.

---

## Future Enhancements

- Adjustable Program Home columns (left/right resize) using a custom LWC splitter container.
- Add `Split.js` as a static resource and initialize it in LWC via `lightning/platformResourceLoader` for drag-to-resize behavior.
- Persist user-specific pane width preferences (for example via `localStorage` first, then a user preference object for cross-device persistence).
- Add responsive presets for common breakpoints (desktop, laptop, tablet) so card readability remains stable.
- Add a "Reset Layout" quick action to restore default pane widths.

### Implementation Checklist

#### Phase 1 — Core Resizable Layout
- [ ] Create `pmHomeLayoutShell` LWC to host left/right panes in a single region.
- [ ] Add `Split.js` as a static resource (`splitjs`) and load it with `loadScript`.
- [ ] Wire left pane to `pmKpiScorecard` and right pane to `pmPortfolioLeadHome`.
- [ ] Configure min/max pane sizes and gutter drag behavior.
- [ ] Add fallback static 60/40 layout if script load fails.

#### Phase 2 — Preference Persistence and UX
- [ ] Save pane widths to `localStorage` on drag end.
- [ ] Restore saved pane widths on component init.
- [ ] Add "Reset Layout" button to return to defaults.
- [ ] Add responsive breakpoint rules (stacked layout under tablet width).
- [ ] Add smoke tests for load, drag, save, restore, and reset behavior.

---

## Executive Employee Experience Site

Build an Executive employee experience in Experience Cloud that mirrors the design direction in `docs/executive-dashboard-prototype-2.html` (reference requested as `docs/executive-dashboard-prototype2.html`).

### Experience Site Goals

- Deliver a clean executive landing experience with KPI-first storytelling and clear navigation.
- Match the Callisto-inspired visual language from the prototype (header treatment, card styles, spacing, and typography rhythm).
- Surface the same executive metrics and dashboard context used in the PM Executive app.
- Keep the layout responsive so desktop and tablet experiences remain visually consistent.

### Scope for Initial Version

- Experience Cloud site setup (template selection, domain, branding, and navigation).
- Executive Home page with hero/banner section and KPI summary cards.
- Embedded dashboard/report tiles aligned to executive KPI priorities.
- Quick access links to Programs, Risks/Cases, and top-level portfolio health views.
- Role-based visibility so executive users see read-focused content.

### Implementation Checklist

- [ ] Create Experience Cloud site for Executive users and configure branding theme.
- [ ] Recreate key layout regions from `docs/executive-dashboard-prototype-2.html`.
- [ ] Add LWC and/or dashboard components for KPI cards and trend visuals.
- [ ] Configure audience/permission access model for executive personas.
- [ ] Add UAT pass for desktop/tablet responsiveness and visual parity with prototype.

### Executive Command Center Interactivity Tracking

#### Phase 1 — Hero/Banner Interactivity Hardening
- [ ] Introduce shared `uiState` filter model in `pmExecutiveExperienceHome`.
- [ ] Unify hero interactions with `data-filter-type` + `data-filter-value`.
- [ ] Add hero `Reset Filters` action.
- [ ] Add keyboard-accessible interactive hero controls with clear active states.
- [ ] Validate: hero controls update one canonical filter state.

#### Phase 2 — Cross-Widget Global Filtering
- [ ] Propagate shared filters to programs, phase strip, transitions, evidence, and UPE views.
- [ ] Ensure key KPI cards read from scoped datasets where applicable.
- [ ] Add empty-state messaging for filtered views with no records.
- [ ] Validate: no contradictory totals across visible sections under active filters.

#### Phase 3 — Click-To-Drill Interactions
- [ ] Add drill interactions from phase strip and major KPI/watch cards.
- [ ] Add visible drill-context pill/breadcrumb near hero.
- [ ] Add one-click drill clear behavior.
- [ ] Validate: summary-to-detail navigation and reversible drill flow.

#### Phase 4 — Trend + Deep-Dive UX
- [ ] Add trend window controls (time window + comparison mode scaffold).
- [ ] Add deep-dive drawer panel for selected KPI/watch details.
- [ ] Add watchlist severity filter and impacted-programs drill action.
- [ ] Validate: drawer and trend controls update without page reload.

---

## Source Layout for Packaging

Experience Cloud metadata is intentionally separated from unlocked-package source.

- `force-app` is the unlocked package source directory (`Portfolio Manager` package).
- `experiences` stores Experience Cloud metadata and is deployed separately.

### Build Unlocked Package (`force-app` only)

Use your existing package version flow. The package is sourced from `force-app` via `sfdx-project.json`.

```bash
sf package version create -p "Portfolio Manager" -x -w 20 -v DevHub
```

### Deploy Experience Site Metadata (`experiences` only)

Deploy site metadata independently to target orgs (scratch/sandbox/prod as needed):

```bash
sf project deploy start -d experiences -o tsx
```

Or use the helper script:

```bash
./scripts/deploy-experience.sh [org-alias]   # default alias: tsx
```

### Recommended Deploy Sequence

1. Install unlocked package (`Portfolio Manager`) into the target org.
2. Assign `PM_Admin` and `PM_Executive` permission sets to the admin user.
3. Load seed data (`load-seed-data.sh`, `load-saturn-data.sh`).
4. Create the Experience Cloud site in Setup → Digital Experiences → New → **Build Your Own (LWR)**.
5. In Experience Builder → Home page: drag `pmExecutiveExperienceHome` into the content region.
6. In Experience Builder → Pages → **+ New Page** → **Record Detail** → select **Program** object. Add the standard Record Detail component. This enables "Go to Program" navigation from the dashboard.
7. In Administration → Members: add `PM_Executive` permission set as a site member.
8. Publish the site.
9. Deploy `experiences` metadata (optional — configures Network/Site settings):
   ```bash
   sf project deploy start -d experiences -o <alias>
   ```

> **Note:** Steps 4–8 are performed in the Salesforce UI and cannot be scripted via metadata deploy. The ExperienceBundle metadata type is not supported in unlocked packages.

### Automation Script: Package Install + Permset Assignment

Use this helper to install package metadata and assign required permission sets for your executive demo user:

```bash
./scripts/deploy-package-and-permsets.sh -o tsx -u brian.smith@demo.vrm -p PM_Executive
```

If you omit `-v`, the script resolves the latest package version for `Portfolio Manager` automatically.

### Automation Script: Executive Command Center Smoke Check

Use this helper to run quick org-side checks and print the interactive UI validation path:

```bash
./scripts/smoke-exec-command-center.sh [org-alias] [/experience-path]
# example
./scripts/smoke-exec-command-center.sh tsx /titanx
```

---

## Salesforce DX Project: Next Steps

Now that you’ve created a Salesforce DX project, what’s next? Here are some documentation resources to get you started.

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)
