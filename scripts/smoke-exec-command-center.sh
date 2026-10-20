#!/usr/bin/env bash
# smoke-exec-command-center.sh
# Quick smoke helper for Executive Command Center readiness.
#
# Usage:
#   ./scripts/smoke-exec-command-center.sh [org-alias] [experience-path]
#
# Defaults:
#   org-alias       tsx
#   experience-path /titanx

set -euo pipefail

ORG="${1:-tsx}"
EXP_PATH="${2:-/titanx}"

echo ""
echo "========================================"
echo " Executive Command Center Smoke Check"
echo " Target org     : $ORG"
echo " Experience path: $EXP_PATH"
echo "========================================"
echo ""

echo "[1/4] Verify required Apex class exists..."
sf data query --use-tooling-api \
  --target-org "$ORG" \
  --query "SELECT Name, ApiVersion FROM ApexClass WHERE Name = 'PmDashboardController'"
echo ""

echo "[2/4] Verify key permission set assignments..."
sf data query \
  --target-org "$ORG" \
  --query "SELECT Assignee.Username, PermissionSet.Name FROM PermissionSetAssignment WHERE PermissionSet.Name IN ('PM_Executive','PM_Admin','PM_Analyst') ORDER BY PermissionSet.Name, Assignee.Username"
echo ""

echo "[3/4] Verify baseline pm_Program__c data is available..."
sf data query \
  --target-org "$ORG" \
  --query "SELECT COUNT(Id) totalPrograms FROM pm_Program__c"
echo ""

echo "[4/4] Manual UI walkthrough checkpoints"
echo "Open the site: $EXP_PATH"
echo "  - Hero filters: Active Programs -> Transition Focus -> All Programs"
echo "  - Reset Filters restores baseline state"
echo "  - Phase strip drill shows Drill pill; Clear Drill removes it"
echo "  - Speed Trend controls update values without reload"
echo "  - KPI Drill opens deep-dive drawer; Close works"
echo "  - Watch severity filter + Impacted drill narrows program view"
echo ""
echo "Smoke check complete."
echo ""
