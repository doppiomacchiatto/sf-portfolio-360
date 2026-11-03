#!/usr/bin/env bash
# install-package.sh
# Installs the latest Portfolio 360 package version from sfdx-project.json
# into a target org.
#
# Usage:
#   ./scripts/install-package.sh [options]
#   ./scripts/install-package.sh <org-alias>
#
# Examples:
#   ./scripts/install-package.sh pm-scratch
#   ./scripts/install-package.sh -o hyperion
#   ./scripts/install-package.sh -o pm-scratch -v 04tg7000000cST7AAM
#
# Defaults:
#   org alias:   pm-scratch
#   version id:  latest "Portfolio 360@..." alias in sfdx-project.json (last 04t entry)
#   wait:        20 minutes

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/sfdx-project.json"

ORG_ALIAS="pm-scratch"
PACKAGE_VERSION_ID=""
WAIT_MINUTES=20
PUBLISH_WAIT_MINUTES=10

print_help() {
  cat <<'EOF'
Install the Portfolio 360 unlocked package into a target org.

Resolves the package version from sfdx-project.json packageAliases:
uses the latest "Portfolio 360@<version>" entry (04t...), unless -v is passed.

Usage:
  ./scripts/install-package.sh [options]
  ./scripts/install-package.sh <org-alias>

Options:
  -o, --org <alias>       Target org alias (default: pm-scratch)
  -v, --version-id <04t>  Subscriber package version id (optional override)
  -w, --wait <minutes>    Install wait minutes (default: 20)
  -h, --help              Show help

Examples:
  ./scripts/install-package.sh pm-scratch
  ./scripts/install-package.sh -o hyperion
  ./scripts/install-package.sh -o pm-scratch -v 04tg7000000cST7AAM
EOF
}

resolve_latest_version() {
  if [[ ! -f "$PROJECT_FILE" ]]; then
    echo "Error: sfdx-project.json not found at $PROJECT_FILE" >&2
    exit 1
  fi

  python3 - "$PROJECT_FILE" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
aliases = json.loads(path.read_text(encoding="utf-8")).get("packageAliases") or {}

versioned = []
for key, value in aliases.items():
    if not isinstance(value, str) or not value.startswith("04t"):
        continue
    m = re.match(r"^Portfolio 360@(\d+)\.(\d+)\.(\d+)-(\d+)$", key)
    if not m:
        continue
    major, minor, patch, build = (int(x) for x in m.groups())
    versioned.append(((major, minor, patch, build), key, value))

if not versioned:
    print("ERROR: No Portfolio 360@x.y.z-N (04t...) aliases found in sfdx-project.json", file=sys.stderr)
    sys.exit(1)

versioned.sort(key=lambda row: row[0])
_, alias, version_id = versioned[-1]
print(f"{alias}\t{version_id}")
PY
}

# Positional org alias support: ./scripts/install-package.sh pm-scratch
if [[ $# -eq 1 && "$1" != -* ]]; then
  ORG_ALIAS="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--org)
      ORG_ALIAS="${2:-}"; shift 2 ;;
    -v|--version-id)
      PACKAGE_VERSION_ID="${2:-}"; shift 2 ;;
    -w|--wait)
      WAIT_MINUTES="${2:-}"; shift 2 ;;
    -h|--help)
      print_help; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      print_help
      exit 1 ;;
  esac
done

if [[ -z "$ORG_ALIAS" ]]; then
  echo "Error: org alias is required." >&2
  print_help
  exit 1
fi

PACKAGE_ALIAS_LABEL=""
if [[ -z "$PACKAGE_VERSION_ID" ]]; then
  RESOLVED="$(resolve_latest_version)"
  PACKAGE_ALIAS_LABEL="${RESOLVED%%$'\t'*}"
  PACKAGE_VERSION_ID="${RESOLVED#*$'\t'}"
fi

echo ""
echo "========================================="
echo "  PM Portfolio 360 — Package Install"
echo "  Target org : $ORG_ALIAS"
if [[ -n "$PACKAGE_ALIAS_LABEL" ]]; then
  echo "  Version    : $PACKAGE_ALIAS_LABEL"
fi
echo "  Package ID : $PACKAGE_VERSION_ID"
echo "  Wait       : ${WAIT_MINUTES}m"
echo "========================================="
echo ""

sf package install \
  --package "$PACKAGE_VERSION_ID" \
  --target-org "$ORG_ALIAS" \
  --wait "$WAIT_MINUTES" \
  --publish-wait "$PUBLISH_WAIT_MINUTES" \
  --no-prompt

echo ""
echo "Install complete."
echo "  Org     : $ORG_ALIAS"
echo "  Package : $PACKAGE_VERSION_ID"
echo ""
