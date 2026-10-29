#!/usr/bin/env bash
# create-test-user.sh
# Creates the standard demo/test user for a sandbox, if it doesn't already exist.
#
# Usage:
#   ./scripts/create-test-user.sh [options]
#
# Examples:
#   ./scripts/create-test-user.sh -o hyperion
#   ./scripts/create-test-user.sh -o rhea -u brian.smith@demo.vrm.rhea
#
# Defaults:
#   org alias:  (required)
#   username:   brian.smith@demo.vrm.<org alias>
#   first/last: Brian / Smith
#   alias:      bsmit
#   email:      doppiomacchiatto@example.com
#   profile:    PM_Standard if it exists in the org, else Standard User
#
# Notes:
# - Idempotent: if the username already exists in the target org, this is a no-op.

set -euo pipefail

ORG_ALIAS=""
TARGET_USER=""
FIRST_NAME="Brian"
LAST_NAME="Smith"
ALIAS_FIELD="bsmit"
EMAIL="doppiomacchiatto@example.com"
PROFILE_NAME=""

print_help() {
  cat <<'EOF'
Create the standard demo/test user (brian.smith) for a sandbox, if missing.

Options:
  -o, --org <alias>       Target org alias (required)
  -u, --user <username>   Username to create (default: brian.smith@demo.vrm.<org alias>)
  -p, --profile <name>    Profile name (default: PM_Standard if present, else Standard User)
  -h, --help               Show help

Examples:
  ./scripts/create-test-user.sh -o hyperion
  ./scripts/create-test-user.sh -o rhea -u brian.smith@demo.vrm.rhea
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--org)
      ORG_ALIAS="${2:-}"; shift 2 ;;
    -u|--user)
      TARGET_USER="${2:-}"; shift 2 ;;
    -p|--profile)
      PROFILE_NAME="${2:-}"; shift 2 ;;
    -h|--help)
      print_help; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      print_help
      exit 1 ;;
  esac
done

if [[ -z "$ORG_ALIAS" ]]; then
  echo "Error: -o/--org is required." >&2
  print_help
  exit 1
fi

if [[ -z "$TARGET_USER" ]]; then
  TARGET_USER="brian.smith@demo.vrm.${ORG_ALIAS}"
fi

echo ""
echo "========================================"
echo " PM Portfolio 360 — Create Test User"
echo " Target org : $ORG_ALIAS"
echo " Username   : $TARGET_USER"
echo "========================================"
echo ""

echo "[1/3] Checking whether '$TARGET_USER' already exists in '$ORG_ALIAS'..."
EXISTING_ID="$(sf data query -q "SELECT Id FROM User WHERE Username = '$TARGET_USER'" --target-org "$ORG_ALIAS" --json \
  | jq -r '.result.records[0].Id // empty')"

if [[ -n "$EXISTING_ID" ]]; then
  echo "    Already exists: $EXISTING_ID. Nothing to do."
  exit 0
fi
echo "    Not found. Will create."
echo ""

echo "[2/3] Resolving profile..."
if [[ -z "$PROFILE_NAME" ]]; then
  PM_STANDARD_ID="$(sf data query -q "SELECT Id FROM Profile WHERE Name = 'PM_Standard'" --target-org "$ORG_ALIAS" --json \
    | jq -r '.result.records[0].Id // empty')"
  if [[ -n "$PM_STANDARD_ID" ]]; then
    PROFILE_NAME="PM_Standard"
    PROFILE_ID="$PM_STANDARD_ID"
  else
    PROFILE_NAME="Standard User"
  fi
fi

if [[ -z "${PROFILE_ID:-}" ]]; then
  PROFILE_ID="$(sf data query -q "SELECT Id FROM Profile WHERE Name = '$PROFILE_NAME'" --target-org "$ORG_ALIAS" --json \
    | jq -r '.result.records[0].Id // empty')"
fi

if [[ -z "$PROFILE_ID" ]]; then
  echo "    Not found: no profile named '$PROFILE_NAME' in '$ORG_ALIAS'." >&2
  exit 1
fi
echo "    Using profile: $PROFILE_NAME ($PROFILE_ID)"
echo ""

echo "[3/3] Creating user '$TARGET_USER'..."
sf data create record -s User --target-org "$ORG_ALIAS" -v \
  "Username='$TARGET_USER' FirstName='$FIRST_NAME' LastName='$LAST_NAME' Alias='$ALIAS_FIELD' Email='$EMAIL' TimeZoneSidKey='America/New_York' LocaleSidKey='en_US' EmailEncodingKey='UTF-8' LanguageLocaleKey='en_US' ProfileId='$PROFILE_ID'"
echo ""

echo "Complete."
echo ""
