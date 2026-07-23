#!/usr/bin/env bash
# deploy-package-and-permsets.sh
# Installs a package version and assigns permission sets to a user.
#
# Usage:
#   ./scripts/deploy-package-and-permsets.sh [options]
#
# Examples:
#   ./scripts/deploy-package-and-permsets.sh
#   ./scripts/deploy-package-and-permsets.sh -o tsx -u brian.smith@demo.vrm
#   ./scripts/deploy-package-and-permsets.sh -o tsx -v 04tKY000000ZSB1YAO -p PM_Executive,PM_Analyst
#
# Defaults:
#   org alias:      tsx
#   package alias:  Portfolio Manager
#   target user:    brian.smith@demo.vrm
#   permsets:       PM_Executive
#   wait minutes:   20
#
# Notes:
# - If -v/--version-id is omitted, the script resolves the latest package version
#   for --package-alias from the Dev Hub via `sf package version list`.
# - Existing permission set assignments are skipped safely.

set -euo pipefail

ORG_ALIAS="tsx"
PACKAGE_ALIAS="Portfolio Manager"
PACKAGE_VERSION_ID=""
TARGET_USER="brian.smith@demo.vrm"
PERMSETS_CSV="PM_Executive"
WAIT_MINUTES=20
PUBLISH_WAIT_MINUTES=10
DEVHUB_ALIAS="vrm"

print_help() {
  cat <<'EOF'
Install package + assign permission sets.

Options:
  -o, --org <alias>            Target org alias (default: tsx)
  -a, --package-alias <name>   Package alias/name (default: Portfolio Manager)
  -v, --version-id <04t...>    Subscriber package version id (optional)
  -u, --user <username>        Username to assign permsets to (default: brian.smith@demo.vrm)
  -p, --permsets <csv>         Comma-separated permsets (default: PM_Executive)
  -w, --wait <minutes>         Install wait minutes (default: 20)
  -h, --help                   Show help

Examples:
  ./scripts/deploy-package-and-permsets.sh
  ./scripts/deploy-package-and-permsets.sh -o tsx -u brian.smith@demo.vrm
  ./scripts/deploy-package-and-permsets.sh -v 04tXXXXXXXXXXXX -p PM_Executive,PM_Analyst
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--org)
      ORG_ALIAS="${2:-}"; shift 2 ;;
    -a|--package-alias)
      PACKAGE_ALIAS="${2:-}"; shift 2 ;;
    -v|--version-id)
      PACKAGE_VERSION_ID="${2:-}"; shift 2 ;;
    -u|--user)
      TARGET_USER="${2:-}"; shift 2 ;;
    -p|--permsets)
      PERMSETS_CSV="${2:-}"; shift 2 ;;
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

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo ""
echo "========================================"
echo " PM Portfolio Manager — Deploy + Access"
echo " Target org       : $ORG_ALIAS"
echo " Target user      : $TARGET_USER"
echo " Package alias    : $PACKAGE_ALIAS"
echo " Wait minutes     : $WAIT_MINUTES"
echo " Permission sets  : $PERMSETS_CSV"
echo "========================================"
echo ""

if [[ -z "$PACKAGE_VERSION_ID" ]]; then
  echo "[1/3] Resolving latest package version for '$PACKAGE_ALIAS' from Dev Hub '$DEVHUB_ALIAS'..."
  sf package version list -p "$PACKAGE_ALIAS" -v "$DEVHUB_ALIAS" --json > /tmp/pm_package_versions.json
  PACKAGE_VERSION_ID="$(python3 - <<'PY'
import json, re
obj=json.load(open('/tmp/pm_package_versions.json'))
rows=obj.get('result', [])
if not rows:
    raise SystemExit("No package versions returned.")
def key(v):
    ver=v.get('Version') or ""
    nums=[int(x) for x in re.findall(r'\d+', ver)]
    while len(nums) < 4:
        nums.append(0)
    return tuple(nums[:4])
latest=max(rows, key=key)
spv=latest.get('SubscriberPackageVersionId')
if not spv:
    raise SystemExit("Latest package row missing SubscriberPackageVersionId.")
print(spv)
PY
)"
  echo "    Latest package version id: $PACKAGE_VERSION_ID"
else
  echo "[1/3] Using provided package version id: $PACKAGE_VERSION_ID"
fi
echo ""

echo "[2/3] Installing package into org '$ORG_ALIAS'..."
sf package install \
  --package "$PACKAGE_VERSION_ID" \
  --target-org "$ORG_ALIAS" \
  --wait "$WAIT_MINUTES" \
  --publish-wait "$PUBLISH_WAIT_MINUTES" \
  --no-prompt
echo ""

echo "[3/3] Assigning permission sets to '$TARGET_USER'..."
IFS=',' read -r -a PERMSETS <<< "$PERMSETS_CSV"
for permset in "${PERMSETS[@]}"; do
  permset="$(echo "$permset" | xargs)"
  [[ -z "$permset" ]] && continue

  if sf org assign permset --name "$permset" --target-org "$ORG_ALIAS" --on-behalf-of "$TARGET_USER" >/tmp/pm_assign.out 2>&1; then
    echo "    Assigned: $permset"
  else
    if rg -n "Duplicate PermissionSetAssignment" /tmp/pm_assign.out >/dev/null; then
      echo "    Already assigned: $permset"
    else
      echo "Failed to assign permset '$permset':" >&2
      sed 's/^/    /' /tmp/pm_assign.out >&2
      exit 1
    fi
  fi
done
echo ""

echo "Complete."
echo "Next: publish the Experience site and hard refresh."
echo ""
