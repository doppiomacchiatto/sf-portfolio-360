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
#   package alias:  Portfolio 360
#   target user:    brian.smith@demo.vrm.<org alias>  (per-sandbox username convention)
#   permsets:       PM_Executive
#   wait minutes:   20
#
# Notes:
# - If -v/--version-id is omitted, the script resolves the latest package version
#   for --package-alias from the Dev Hub via `sf package version list`.
# - Existing permission set assignments are skipped safely.
# - Before installing, the script compares the currently installed version in
#   the target org against the version about to be installed. If they're the
#   same (no-op) or the target is older (downgrade), it aborts unless -f/--force
#   is passed.
# - Test users (e.g. brian.smith) follow a per-sandbox username suffix
#   convention: brian.smith@demo.vrm.<org alias>. If -u/--user is omitted, the
#   default is derived from --org. Pass -u explicitly to override.

set -euo pipefail

ORG_ALIAS=""
PACKAGE_ALIAS="Portfolio 360"
PACKAGE_VERSION_ID=""
TARGET_USER=""
PERMSETS_CSV="PM_Executive"
WAIT_MINUTES=20
PUBLISH_WAIT_MINUTES=10
DEVHUB_ALIAS="vrm"
FORCE=false

print_help() {
  cat <<'EOF'
Install package + assign permission sets.

Options:
  -o, --org <alias>            Target org alias (default: tsx)
  -a, --package-alias <name>   Package alias/name (default: Portfolio 360)
  -v, --version-id <04t...>    Subscriber package version id (optional)
  -u, --user <username>        Username to assign permsets to (default: brian.smith@demo.vrm.<org alias>)
  -p, --permsets <csv>         Comma-separated permsets (default: PM_Executive)
  -w, --wait <minutes>         Install wait minutes (default: 20)
  -f, --force                  Install even if target version is already installed or older
  -h, --help                   Show help

Examples:
  ./scripts/deploy-package-and-permsets.sh -o hyperion
  ./scripts/deploy-package-and-permsets.sh -o hyperion -u brian.smith@demo.vrm.hyperion
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
    -f|--force)
      FORCE=true; shift 1 ;;
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

if [[ -z "$TARGET_USER" ]]; then
  TARGET_USER="brian.smith@demo.vrm.${ORG_ALIAS}"
fi

echo ""
echo "========================================"
echo " PM Portfolio 360 — Deploy + Access"
echo " Target org       : $ORG_ALIAS"
echo " Target user      : $TARGET_USER"
echo " Package alias    : $PACKAGE_ALIAS"
echo " Wait minutes     : $WAIT_MINUTES"
echo " Permission sets  : $PERMSETS_CSV"
echo "========================================"
echo ""

echo "[1/6] Fetching package versions for '$PACKAGE_ALIAS' from Dev Hub '$DEVHUB_ALIAS'..."
sf package version list -p "$PACKAGE_ALIAS" -v "$DEVHUB_ALIAS" --json > /tmp/pm_package_versions.json

if [[ -z "$PACKAGE_VERSION_ID" ]]; then
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
  echo "    Using provided package version id: $PACKAGE_VERSION_ID"
fi
echo ""

echo "[2/6] Comparing against currently installed version in org '$ORG_ALIAS'..."
PACKAGE2_ID="$(jq -r --arg alias "$PACKAGE_ALIAS" '.packageAliases[$alias] // empty' "$ROOT_DIR/sfdx-project.json")"
DEVHUB_PACKAGE_NAME="$(sf package list --target-dev-hub "$DEVHUB_ALIAS" --json \
  | jq -r --arg id "$PACKAGE2_ID" '.result[] | select(.Id == $id) | .Name' | head -n1)"
INSTALLED_VERSION_ID="$(sf package installed list --target-org "$ORG_ALIAS" --json \
  | jq -r --arg name "$DEVHUB_PACKAGE_NAME" '.result[] | select(.SubscriberPackageName == $name) | .SubscriberPackageVersionId' | head -n1)"

if [[ -z "$INSTALLED_VERSION_ID" ]]; then
  echo "    Not currently installed in '$ORG_ALIAS'. Proceeding with fresh install."
else
  COMPARE_RESULT="$(python3 - "$INSTALLED_VERSION_ID" "$PACKAGE_VERSION_ID" <<'PY'
import json, re, sys
installed_id, target_id = sys.argv[1], sys.argv[2]
rows = json.load(open('/tmp/pm_package_versions.json')).get('result', [])
by_id = {r.get('SubscriberPackageVersionId'): r for r in rows}

def numkey(ver):
    nums = [int(x) for x in re.findall(r'\d+', ver or "")]
    while len(nums) < 4:
        nums.append(0)
    return tuple(nums[:4])

installed_ver = by_id.get(installed_id, {}).get('Version', '(unknown)')
target_ver = by_id.get(target_id, {}).get('Version', '(unknown)')
print(f"installed={installed_ver}")
print(f"target={target_ver}")
if installed_id == target_id:
    print("verdict=same")
elif numkey(installed_ver) > numkey(target_ver):
    print("verdict=downgrade")
else:
    print("verdict=upgrade")
PY
)"
  INSTALLED_VER="$(echo "$COMPARE_RESULT" | sed -n 's/^installed=//p')"
  TARGET_VER="$(echo "$COMPARE_RESULT" | sed -n 's/^target=//p')"
  VERDICT="$(echo "$COMPARE_RESULT" | sed -n 's/^verdict=//p')"
  echo "    Currently installed: $INSTALLED_VER ($INSTALLED_VERSION_ID)"
  echo "    Target version:      $TARGET_VER ($PACKAGE_VERSION_ID)"

  if [[ "$VERDICT" != "upgrade" && "$FORCE" != "true" ]]; then
    if [[ "$VERDICT" == "same" ]]; then
      echo "    Target version is already installed. This would be a no-op. Pass -f/--force to reinstall anyway." >&2
    else
      echo "    Target version ($TARGET_VER) is older than what's installed ($INSTALLED_VER). Refusing to downgrade. Pass -f/--force to override." >&2
    fi
    exit 1
  fi
fi
echo ""

echo "[3/6] Installing package into org '$ORG_ALIAS'..."
sf package install \
  --package "$PACKAGE_VERSION_ID" \
  --target-org "$ORG_ALIAS" \
  --wait "$WAIT_MINUTES" \
  --publish-wait "$PUBLISH_WAIT_MINUTES" \
  --no-prompt
echo ""

echo "[4/6] Recording deployment in control file..."
DEPLOY_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TARGET_VERSION_NUMBER="$(jq -r --arg id "$PACKAGE_VERSION_ID" '.result[] | select(.SubscriberPackageVersionId == $id) | .Version' /tmp/pm_package_versions.json | head -n1)"
ORG_IDENTITY_JSON="$(sf org display user --target-org "$ORG_ALIAS" --json)"
DEPLOYING_ORG_ID="$(echo "$ORG_IDENTITY_JSON" | jq -r '.result.orgId')"
DEPLOYING_USER_ID="$(echo "$ORG_IDENTITY_JSON" | jq -r '.result.id')"
DEPLOYING_USERNAME="$(echo "$ORG_IDENTITY_JSON" | jq -r '.result.username')"

jq -nc \
  --arg timestamp "$DEPLOY_TIMESTAMP" \
  --arg orgAlias "$ORG_ALIAS" \
  --arg orgId "$DEPLOYING_ORG_ID" \
  --arg userId "$DEPLOYING_USER_ID" \
  --arg username "$DEPLOYING_USERNAME" \
  --arg packageAlias "$PACKAGE_ALIAS" \
  --arg packageVersionId "$PACKAGE_VERSION_ID" \
  --arg packageVersionNumber "$TARGET_VERSION_NUMBER" \
  '{timestamp: $timestamp, orgAlias: $orgAlias, orgId: $orgId, userId: $userId, username: $username, packageAlias: $packageAlias, packageVersionId: $packageVersionId, packageVersionNumber: $packageVersionNumber}' \
  >> "$ROOT_DIR/scripts/deploy-history.jsonl"
echo "    Logged to scripts/deploy-history.jsonl"
echo ""

echo "[5/6] Ensuring target user exists..."
"$ROOT_DIR/scripts/create-test-user.sh" -o "$ORG_ALIAS" -u "$TARGET_USER"
echo ""

echo "[6/6] Assigning permission sets to '$TARGET_USER'..."
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
