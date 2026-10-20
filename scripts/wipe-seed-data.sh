#!/usr/bin/env bash
# wipe-seed-data.sh — Delete all seed data from the target org.
# Usage: ./scripts/wipe-seed-data.sh [org-alias]
#   org-alias defaults to "tsx"
#
# Deletes children before parents to avoid FK constraint errors.
# Run ./scripts/load-seed-data.sh after this to restore the demo state.

set -euo pipefail

ORG="${1:-tsx}"

echo ""
echo "========================================"
echo "  PM Portfolio 360 — Wipe Seed Data"
echo "  Target org : $ORG"
echo "========================================"
echo ""

delete_object() {
  local obj="$1"
  local tmpfile
  tmpfile=$(mktemp /tmp/pm_wipe_XXXX.csv)

  echo "Id" > "$tmpfile"
  sf data query \
    --query "SELECT Id FROM $obj" \
    --target-org "$ORG" \
    --json 2>/dev/null \
    | python3 -c "
import json, sys
records = json.load(sys.stdin).get('result', {}).get('records', [])
for r in records:
    print(r['Id'])
" >> "$tmpfile"

  local count
  count=$(tail -n +2 "$tmpfile" | grep -c . || true)

  if [ "$count" -gt 0 ]; then
    echo "[$obj] Deleting $count records..."
    sf data delete bulk \
      --sobject "$obj" \
      --file "$tmpfile" \
      --target-org "$ORG" \
      --wait 5 2>&1 | grep -E "JobComplete|Failed|Error|records deleted" || true
  else
    echo "[$obj] No records found — skipping."
  fi

  rm -f "$tmpfile"
}

delete_object pm_Project_Transition__c
delete_object pm_User_Partner_Engagement__c
delete_object pm_Evidence__c
delete_object pm_Technical_Exam__c
delete_object pm_MRL__c
delete_object pm_TRL__c
delete_object pm_Program__c

echo ""
echo "========================================"
echo "  Wipe complete."
echo "  Reload with: ./scripts/load-seed-data.sh $ORG"
echo "========================================"
echo ""
