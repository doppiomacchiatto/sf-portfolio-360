#!/usr/bin/env bash
# load-seed-data.sh — Load demo seed data into the target org.
# Usage: ./scripts/load-seed-data.sh [org-alias]
#   org-alias defaults to "tsx"
#
# What it loads (7 programs, full relationship tree):
#   SIGMA-1    Ideation        Validated / Disruptive High Risk
#   NEXUS-4    Funded          Approved Critical Tech / Mission Pull
#   SHIELD-X   Awarded         Security-Gap / Near Term
#   FORGE      Prototype       Threat-Informed / Defense Unique
#   APEX-7     Demo Complete   Threat-Informed / Near Term
#   CLARITY    Demo Complete → Transitioning (auto-set by TRL≥7 flow)
#   VECTOR     Operational     Validated / Near Term
#
# Post-load note: The Update_Program_Status_from_TRL flow fires on TRL create,
# so CLARITY and VECTOR will both land as "Transitioning" after their TRL records
# are saved. The script re-asserts VECTOR's status to "Operational" when done.

set -euo pipefail

ORG="${1:-pm-scratch}"
PLAN_DIR="$(cd "$(dirname "$0")/../data/seed" && pwd)"

echo ""
echo "========================================"
echo "  PM Portfolio 360 — Seed Data Load"
echo "  Target org : $ORG"
echo "  Plan dir   : $PLAN_DIR"
echo "========================================"
echo ""

# ── Step 1: Import all records via the data plan ──────────────────────────────
echo "[1/3] Importing records via data plan..."
sf data import tree \
  --plan "$PLAN_DIR/seed-plan.json" \
  --target-org "$ORG"
echo ""

# ── Step 2: Re-assert VECTOR status ──────────────────────────────────────────
# The TRL flow (triggered on pm_TRL__c create) sets Program_Status__c = Transitioning
# whenever Current_TRL__c >= 7. CLARITY (TRL 8) should stay Transitioning — that's
# correct. VECTOR (TRL 9) needs to be Operational since it completed the full cycle.
echo "[2/3] Re-asserting VECTOR status to Operational (overrides TRL flow)..."
VECTOR_ID=$(sf data query \
  --query "SELECT Id FROM pm_Program__c WHERE Name = 'VECTOR' LIMIT 1" \
  --target-org "$ORG" \
  --json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['records'][0]['Id'])")

sf data update record \
  --sobject pm_Program__c \
  --record-id "$VECTOR_ID" \
  --values "Program_Status__c='Operational'" \
  --target-org "$ORG"
echo "  VECTOR ($VECTOR_ID) → Operational"
echo ""

# ── Step 3: Print summary ─────────────────────────────────────────────────────
echo "[3/3] Verifying record counts..."
sf data query \
  --query "SELECT Program_Status__c status, COUNT(Id) cnt FROM pm_Program__c GROUP BY Program_Status__c ORDER BY COUNT(Id) DESC" \
  --target-org "$ORG"

echo ""
sf data query \
  --query "SELECT COUNT(Id) trl FROM pm_TRL__c" \
  --target-org "$ORG"
sf data query \
  --query "SELECT COUNT(Id) mrl FROM pm_MRL__c" \
  --target-org "$ORG"
sf data query \
  --query "SELECT COUNT(Id) exams FROM pm_Technical_Exam__c" \
  --target-org "$ORG"
sf data query \
  --query "SELECT COUNT(Id) evidence FROM pm_Evidence__c" \
  --target-org "$ORG"
sf data query \
  --query "SELECT COUNT(Id) upe FROM pm_User_Partner_Engagement__c" \
  --target-org "$ORG"
sf data query \
  --query "SELECT COUNT(Id) transitions FROM pm_Project_Transition__c" \
  --target-org "$ORG"

echo ""
echo "========================================"
echo "  Seed load complete."
echo ""
echo "  Demo moments to show live:"
echo "  1. Open APEX-7 → add TRL record with Current_TRL=7"
echo "     → watch Program_Status flip to Transitioning (automation)"
echo "  2. Open CLARITY's Project Transition → check Transition_Commitment_Complete"
echo "     → Program owner receives email alert (automation)"
echo "========================================"
echo ""
