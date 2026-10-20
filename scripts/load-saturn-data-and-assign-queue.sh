#!/usr/bin/env bash
# load-saturn-data-and-assign-queue.sh
# Loads Saturn moon demo data, then (only if that succeeds) reassigns the
# Saturn programs to the pm_Saturn_Programs queue via anonymous Apex.
#
# Usage: ./scripts/load-saturn-data-and-assign-queue.sh [org-alias]
#   org-alias defaults to "pm-scratch"

set -euo pipefail

ORG="${1:-pm-scratch}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo "============================================="
echo "  PM Portfolio 360 — Saturn Load + Queue Assign"
echo "  Target org : $ORG"
echo "============================================="
echo ""

echo "[1/2] Loading Saturn demo data..."
"$ROOT_DIR/scripts/load-saturn-data.sh" "$ORG"
echo ""

echo "[2/2] Assigning Saturn programs to pm_Saturn_Programs queue..."
sf apex run --file "$ROOT_DIR/scripts/assignSaturnProgramsToQueue.apex" --target-org "$ORG"
echo ""

echo "Complete."
echo ""
