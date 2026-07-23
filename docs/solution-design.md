# Portfolio Manager Salesforce Solution Design

## Objective

Build a Program-centric portfolio management application in Salesforce that tracks KPI outcomes and produces executive dashboards, with priority KPI support for:

- KPI #3: Time from Mission Need to Funded Start
- KPI #4: Time from Award to First Prototype
- KPI #12: Prototype to Transition Conversion Rate
- KPI #13: Time from Successful Demo to Mission Use
- KPI #14: Operational Index

## Core Architecture

- **Primary object:** `Program__c`
- **Vendor linkage:** standard `Account` (Vendor record type) via `Program_Vendor__c` junction
- **Risk/issue linkage:** standard `Case` with `Program__c` lookup
- **Operational outcomes:** child object `Operational_Outcome__c` (1:M to Program)
- **Trend analytics:** `Program_KPI_Snapshot__c` (periodic KPI snapshots)

## Data Model

### Program (`Program__c`)

Stores milestone dates, lifecycle status, transition outcome, and KPI formula fields.

Key fields:

- `Program_Status__c`
- `Mission_Need_Validated_Date__c`
- `Funding_Start_Date__c`
- `Award_Date__c`
- `First_Prototype_Date__c`
- `Successful_Demo_Date__c`
- `Mission_Use_Date__c`
- `Time_Mission_to_Funded_Days__c` (formula)
- `Time_Award_to_Prototype_Months__c` (formula)
- `Time_Demo_to_MissionUse_Months__c` (formula)
- `Transition_Outcome__c`
- `Is_Transitioned__c` (formula checkbox)
- `Operational_Index__c` (rollup target)

### Program Vendor (`Program_Vendor__c`)

Junction object linking Programs and Vendor Accounts.

### Operational Outcome (`Operational_Outcome__c`)

Captures measurable operational improvements and contributes to `Operational_Index__c`.

### KPI Snapshot (`Program_KPI_Snapshot__c`)

Stores period-based KPI values for trend reporting and dashboard stability.

## KPI Implementation Notes

- **KPI #3:** date-difference formula on Program; dashboard reports should use median.
- **KPI #4:** date-difference formula (days/30); report medians by quarter.
- **KPI #12:** driven by `Transition_Outcome__c` and `Is_Transitioned__c`.
- **KPI #13:** date-difference formula from demo to mission use.
- **KPI #14:** weighted aggregation from `Operational_Outcome__c` records.

## Automation Strategy

- Record-triggered flow to recalculate operational index from child outcomes.
- Record-triggered flow to create/update KPI breach Cases.
- Scheduled flow to create periodic KPI snapshots.
- Validation rules to enforce date sequence and required transition context.

## Dashboard Strategy

Dashboard: **Portfolio Executive Command View**

Primary components:

- KPI #3 median gauge
- KPI #4 quarterly trend
- KPI #12 conversion donut + metric
- KPI #13 median by vendor/mission segment
- KPI #14 operational index ranking
- Open KPI breach Cases panel

## Deployment Phasing

- **Phase 1:** Core Program object + KPI fields + status model
- **Phase 2:** Related objects, Case integration, and automation
- **Phase 3:** Reports, dashboard, subscriptions, and tuning

## Security and Access

Recommended permission sets:

- Executive Viewer (read analytics)
- Portfolio Manager (full program operations)
- Analyst (controlled edit/create)
- Risk/Support (Case handling)

## Artifacts

Detailed implementation artifacts are provided as CSV files:

- `docs/artifacts-field-spec.csv`
- `docs/artifacts-automation-dashboard.csv`
- `docs/artifacts-report-definitions.csv`
