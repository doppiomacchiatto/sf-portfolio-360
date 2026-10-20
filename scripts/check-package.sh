#!/usr/bin/env bash
# check-package.sh
# Checks whether a package exists on the Dev Hub and/or is installed in a target org.
#
# Usage:
#   ./scripts/check-package.sh [options]
#
# Examples:
#   ./scripts/check-package.sh
#   ./scripts/check-package.sh -o atlas
#   ./scripts/check-package.sh -o atlas -a "Portfolio 360" -v vrm
#
# Defaults:
#   org alias:      atlas
#   package alias:  Portfolio 360   (the local alias in sfdx-project.json's
#                                    packageAliases — NOT the Dev Hub package
#                                    "Name", which may differ, e.g. "Portfolio Manager")
#   devhub alias:   vrm
#
# Exit codes:
#   0  installed in target org
#   1  exists on Dev Hub but not installed in target org
#   2  not found on Dev Hub, or an sf/jq command failed

set -euo pipefail

ORG_ALIAS="atlas"
PACKAGE_ALIAS="Portfolio 360"
DEVHUB_ALIAS="vrm"

print_help() {
  cat <<'EOF'
Check package existence (Dev Hub) and install status (target org).

Resolves the Package2Id from sfdx-project.json's packageAliases (local alias),
confirms it on the Dev Hub, then matches the Dev Hub package's real Name
against the target org's installed packages (SubscriberPackageName).

Options:
  -o, --org <alias>            Target org alias (default: atlas)
  -a, --package-alias <name>   Local package alias from sfdx-project.json (default: Portfolio 360)
  -v, --devhub <alias>         Dev Hub alias (default: vrm)
  -h, --help                   Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--org)
      ORG_ALIAS="${2:-}"; shift 2 ;;
    -a|--package-alias)
      PACKAGE_ALIAS="${2:-}"; shift 2 ;;
    -v|--devhub)
      DEVHUB_ALIAS="${2:-}"; shift 2 ;;
    -h|--help)
      print_help; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      print_help
      exit 2 ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[1/3] Resolving '$PACKAGE_ALIAS' from sfdx-project.json..."
PACKAGE_ID="$(jq -r --arg alias "$PACKAGE_ALIAS" '.packageAliases[$alias] // empty' "$ROOT_DIR/sfdx-project.json")"
if [[ -z "$PACKAGE_ID" ]]; then
  echo "    Not found: no packageAliases entry for '$PACKAGE_ALIAS' in sfdx-project.json."
  exit 2
fi
echo "    Package2Id: $PACKAGE_ID"
echo ""

echo "[2/3] Confirming package exists on Dev Hub '$DEVHUB_ALIAS'..."
PACKAGE_NAME="$(sf package list --target-dev-hub "$DEVHUB_ALIAS" --json \
  | jq -r --arg id "$PACKAGE_ID" '.result[] | select(.Id == $id) | .Name' | head -n1)"

if [[ -z "$PACKAGE_NAME" ]]; then
  echo "    Not found: Package2Id '$PACKAGE_ID' is not on Dev Hub '$DEVHUB_ALIAS'."
  exit 2
fi
echo "    Found: '$PACKAGE_NAME' ($PACKAGE_ID)"
echo ""

echo "[3/3] Checking install status in org '$ORG_ALIAS'..."
INSTALLED_JSON="$(sf package installed list --target-org "$ORG_ALIAS" --json \
  | jq --arg name "$PACKAGE_NAME" '.result[] | select(.SubscriberPackageName == $name)')"

if [[ -z "$INSTALLED_JSON" ]]; then
  echo "    Not installed in '$ORG_ALIAS'."
  exit 1
fi

echo "    Installed in '$ORG_ALIAS':"
echo "$INSTALLED_JSON" | jq -r '"      Version: \(.SubscriberPackageVersionName) (\(.SubscriberPackageVersionId))"'
exit 0
