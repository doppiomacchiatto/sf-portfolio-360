#!/usr/bin/env bash
# deploy-experience.sh — Deploy Experience Cloud metadata from experiences/
# Usage: ./scripts/deploy-experience.sh [org-alias]
#   org-alias defaults to "tsx"

set -euo pipefail

ORG="${1:-tsx}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/experiences"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: Source directory not found: $SRC_DIR" >&2
  exit 1
fi

echo ""
echo "========================================"
echo "  PM Portfolio Manager — Experience Deploy"
echo "  Target org : $ORG"
echo "  Source dir : $SRC_DIR"
echo "========================================"
echo ""

sf project deploy start \
  --source-dir "$SRC_DIR" \
  --target-org "$ORG"

echo ""
echo "Deploy complete."
echo "Next: publish the Experience site in Experience Builder."
echo ""
