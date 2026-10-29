#!/usr/bin/env bash
# configure-site-username.sh
# Sets the Experience site admin / owner username from a required CLI argument.
# Repo defaults use the placeholder changeme@domain.
#
# Usage:
#   ./scripts/configure-site-username.sh <username>
#
# Examples:
#   ./scripts/configure-site-username.sh you@example.com
#   ./scripts/configure-site-username.sh you@vrmrock.demo

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SITE_FILE="$ROOT_DIR/experiences/main/default/sites/titan.site-meta.xml"
PLACEHOLDER="changeme@domain"

print_help() {
  cat <<EOF
Configure Experience site username placeholders in committed metadata.

Usage:
  ./scripts/configure-site-username.sh <username>

Arguments:
  <username>   Salesforce username to write into site admin fields
               (for example: you@vrmrock.demo)

Files updated:
  experiences/main/default/sites/titan.site-meta.xml
    - <siteAdmin>
    - <siteGuestRecordDefaultOwner>

Repo default placeholder: ${PLACEHOLDER}

Examples:
  ./scripts/configure-site-username.sh you@example.com
  ./scripts/configure-site-username.sh you@vrmrock.demo

Options:
  -h, --help   Show this help
EOF
}

if [[ $# -eq 0 ]]; then
  print_help
  exit 1
fi

case "$1" in
  -h|--help)
    print_help
    exit 0
    ;;
  -*)
    echo "Error: unknown option: $1" >&2
    print_help
    exit 1
    ;;
esac

if [[ $# -ne 1 ]]; then
  echo "Error: expected exactly one username argument." >&2
  print_help
  exit 1
fi

USERNAME="$1"

if [[ "$USERNAME" != *@* ]]; then
  echo "Error: username must look like an email (user@domain)." >&2
  print_help
  exit 1
fi

if [[ ! -f "$SITE_FILE" ]]; then
  echo "Error: site metadata not found: $SITE_FILE" >&2
  exit 1
fi

# Escape sed replacement specials: \ & |
USERNAME_ESC="${USERNAME//\\/\\\\}"
USERNAME_ESC="${USERNAME_ESC//&/\\&}"
USERNAME_ESC="${USERNAME_ESC//|/\\|}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  SED_INPLACE=(sed -i '')
else
  SED_INPLACE=(sed -i)
fi

"${SED_INPLACE[@]}" -E \
  "s#(<siteAdmin>)[^<]*(</siteAdmin>)#\\1${USERNAME_ESC}\\2#; s#(<siteGuestRecordDefaultOwner>)[^<]*(</siteGuestRecordDefaultOwner>)#\\1${USERNAME_ESC}\\2#" \
  "$SITE_FILE"

echo ""
echo "========================================="
echo "  Configured site username"
echo "  Username : $USERNAME"
echo "  Site     : $SITE_FILE"
echo "========================================="
echo ""
echo "Updated:"
echo "  - siteAdmin / siteGuestRecordDefaultOwner"
echo ""
