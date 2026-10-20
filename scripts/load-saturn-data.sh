#!/usr/bin/env bash
# load-saturn-data.sh — Load Saturn moon space exploration programs into the target org.
# Usage: ./scripts/load-saturn-data.sh [org-alias]
#   org-alias defaults to "tsx"
#
# What it loads (7 programs — Saturn moon names, space exploration tech):
#   MIMAS       Ideation        Gravitational Wave Navigation System (TRL 2)
#   ENCELADUS   Funded          Zero-Point Energy Extraction Module (TRL 3)
#   TETHYS      Awarded         In-Situ Nanofabrication Swarm (TRL 5)
#   DIONE       Prototype       Cryogenic Suspended Animation Pod (TRL 6)
#   IAPETUS     Demo Complete   Photonic Light Sail Accelerator (TRL 6)
#   RHEA        Transitioning   Quantum Entanglement Communication Array (TRL 8, auto-set by flow)
#   TITAN       Operational     Nuclear Fusion Micro-Thruster Array (TRL 9)
#
# Flow behavior:
#   The Update_Program_Status_from_TRL flow fires on every pm_TRL__c create and sets
#   Program_Status__c = "Transitioning" when Current_TRL >= 7.
#   RHEA (TRL 8) correctly lands as Transitioning — no override needed.
#   TITAN (TRL 9) lands as Transitioning — script re-asserts Operational below.

set -euo pipefail

ORG="${1:-pm-scratch}"
PLAN_DIR="$(cd "$(dirname "$0")/../data/seed/saturn" && pwd)"

echo ""
echo "============================================="
echo "  PM Portfolio 360 — Saturn Data Load"
echo "  Target org : $ORG"
echo "  Plan dir   : $PLAN_DIR"
echo "============================================="
echo ""

# ── Step 1: Import all records via the data plan ──────────────────────────────
echo "[1/3] Importing Saturn moon programs via data plan..."
sf data import tree \
  --plan "$PLAN_DIR/seed-plan.json" \
  --target-org "$ORG"
echo ""

# ── Step 2: Re-assert TITAN status ───────────────────────────────────────────
# TRL flow fires when TITAN's TRL 9 record loads and sets status to Transitioning.
# Re-assert Operational since TITAN has completed the full transition cycle.
echo "[2/3] Re-asserting TITAN status to Operational (overrides TRL flow)..."
TITAN_ID=$(sf data query \
  --query "SELECT Id FROM pm_Program__c WHERE Name = 'TITAN' LIMIT 1" \
  --target-org "$ORG" \
  --json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['result']['records'][0]['Id'])")

sf data update record \
  --sobject pm_Program__c \
  --record-id "$TITAN_ID" \
  --values "Program_Status__c='Operational'" \
  --target-org "$ORG"
echo "  TITAN ($TITAN_ID) → Operational"
echo ""

# ── Step 3: Print summary ─────────────────────────────────────────────────────
echo "[3/3] Verifying record counts (all programs in org)..."
sf data query \
  --query "SELECT Name, Program_Status__c FROM pm_Program__c ORDER BY Name" \
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
echo "============================================="
echo "  Saturn load complete."
echo ""
echo "  Programs loaded:"
echo "  MIMAS      — Gravitational Wave Navigation System"
echo "  ENCELADUS  — Zero-Point Energy Extraction Module"
echo "  TETHYS     — In-Situ Nanofabrication Swarm"
echo "  DIONE      — Cryogenic Suspended Animation Pod"
echo "  IAPETUS    — Photonic Light Sail Accelerator"
echo "  RHEA       — Quantum Entanglement Communication Array"
echo "  TITAN      — Nuclear Fusion Micro-Thruster Array"
echo ""
echo "  Wipe all org data: ./scripts/wipe-seed-data.sh $ORG"
echo "============================================="
echo ""
