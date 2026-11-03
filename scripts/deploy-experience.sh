#!/usr/bin/env bash
# deploy-experience.sh — Deploy Experience Cloud metadata from experiences/
# Usage: ./scripts/deploy-experience.sh [org-alias] [site-username]
#   org-alias defaults to "pm-scratch"
#   site-username defaults to the target org's own username (via `sf org display user`)
#
# Besides the Experience Bundle + Config, this script also:
#   - Deploys the "VRM Administrator" profile referenced by the Network metadata,
#     if it isn't already in the target org.
#   - Fills in the siteAdmin / siteGuestRecordDefaultOwner placeholder
#     (changeme@domain) via configure-site-username.sh, unmodified committed
#     metadata is used for any other target org.
#   - Creates the Experience Cloud site (sf community create) if the target org
#     has no CustomSite/Network yet — a brand-new org has neither, and metadata
#     deploys can't bootstrap them from nothing.
#   - Deploys the Network settings under whatever Network name already exists
#     in the org (a CustomSite can only ever be bound to one Network, and
#     `sf community create` names it after the site, which may differ from the
#     committed networks/*.network-meta.xml file name).

set -euo pipefail

ORG="${1:-pm-scratch}"
SITE_USERNAME="${2:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/experiences"
SRC_DEFAULT_DIR="$SRC_DIR/main/default"
TEMPLATE_NAME="Build Your Own (LWR)"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: Source directory not found: $SRC_DIR" >&2
  exit 1
fi

if [[ -z "$SITE_USERNAME" ]]; then
  SITE_USERNAME="$(sf org display user --target-org "$ORG" --json | jq -r '.result.username')"
fi

echo ""
echo "========================================"
echo "  PM Portfolio 360 — Experience Deploy"
echo "  Target org : $ORG"
echo "  Site admin : $SITE_USERNAME"
echo "  Source dir : $SRC_DIR"
echo "  Deploy mode: Metadata API package"
echo "========================================"
echo ""

if [[ ! -d "$SRC_DEFAULT_DIR" ]]; then
  echo "Error: Expected source directory missing: $SRC_DEFAULT_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- [1/5] VRM Administrator profile -----------------------------------
PROFILE_FILE="$ROOT_DIR/force-app/main/default/profiles/VRM Administrator.profile-meta.xml"
if [[ -f "$PROFILE_FILE" ]]; then
  PROFILE_EXISTS="$(sf data query --query "SELECT Id FROM Profile WHERE Name = 'VRM Administrator'" --target-org "$ORG" --json | jq -r '.result.totalSize')"
  if [[ "$PROFILE_EXISTS" == "0" ]]; then
    echo "[1/5] 'VRM Administrator' profile not found in '$ORG'. Deploying it..."
    PROFILE_DIR="$TMP_DIR/profile-only"
    mkdir -p "$PROFILE_DIR/profiles"
    cp "$PROFILE_FILE" "$PROFILE_DIR/profiles/"
    cat >"$PROFILE_DIR/package.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>VRM Administrator</members>
        <name>Profile</name>
    </types>
    <version>66.0</version>
</Package>
EOF
    sf project deploy start --metadata-dir "$PROFILE_DIR" --target-org "$ORG"
  else
    echo "[1/5] 'VRM Administrator' profile already exists in '$ORG'. Skipping."
  fi
else
  echo "[1/5] 'VRM Administrator' profile not found at $PROFILE_FILE. Skipping."
fi
echo ""

# --- [2/5] Site admin placeholder ---------------------------------------
SITE_FILE="$SRC_DEFAULT_DIR/sites/titan.site-meta.xml"
if [[ -f "$SITE_FILE" ]] && grep -q "changeme@domain" "$SITE_FILE"; then
  echo "[2/5] Configuring site admin username (currently the committed placeholder)..."
  "$ROOT_DIR/scripts/configure-site-username.sh" "$SITE_USERNAME"
else
  echo "[2/5] Site admin username already configured. Skipping."
fi
echo ""

# --- [3/5] Ensure the Experience Cloud site exists ----------------------
SITE_API_NAME="$(basename "$SITE_FILE" .site-meta.xml)"
URL_PATH_PREFIX="$(sed -n 's#.*<urlPathPrefix>\(.*\)</urlPathPrefix>.*#\1#p' "$SRC_DEFAULT_DIR/networks"/*.network-meta.xml | head -n1)"

CUSTOM_SITE_EXISTS="$(sf data query --query "SELECT Id FROM Site WHERE Name = '$SITE_API_NAME'" --target-org "$ORG" --json | jq -r '.result.totalSize')"
if [[ "$CUSTOM_SITE_EXISTS" == "0" ]]; then
  echo "[3/5] No Experience Cloud site named '$SITE_API_NAME' found in '$ORG'. Creating it..."
  echo "       (template: $TEMPLATE_NAME, url path prefix: $URL_PATH_PREFIX)"
  sf community create \
    --name "$SITE_API_NAME" \
    --template-name "$TEMPLATE_NAME" \
    --url-path-prefix "$URL_PATH_PREFIX" \
    --target-org "$ORG" \
    templateParams.AuthenticationType=AUTHENTICATED

  echo "       Waiting for site creation to complete..."
  for _ in $(seq 1 30); do
    SITE_STATUS="$(sf data query --query "SELECT Id FROM Site WHERE Name = '$SITE_API_NAME'" --target-org "$ORG" --json | jq -r '.result.totalSize')"
    [[ "$SITE_STATUS" != "0" ]] && break
    sleep 10
  done
  if [[ "$SITE_STATUS" == "0" ]]; then
    echo "Error: Site creation did not complete in time. Check BackgroundOperation in '$ORG'." >&2
    exit 1
  fi
else
  echo "[3/5] Experience Cloud site '$SITE_API_NAME' already exists in '$ORG'. Skipping creation."
fi
echo ""

# --- [4/5] Resolve the Network name actually bound to this site ---------
# A CustomSite can only be bound to one Network. `sf community create` names
# the Network after the site, which may not match networks/*.network-meta.xml's
# filename (e.g. committed file is "titanx" but the org's Network is "titan").
NETWORK_NAME="$(sf data query --query "SELECT Name FROM Network WHERE Name = '$SITE_API_NAME'" --target-org "$ORG" --json | jq -r '.result.records[0].Name // empty')"
if [[ -z "$NETWORK_NAME" ]]; then
  echo "Error: Could not resolve a Network bound to site '$SITE_API_NAME' in '$ORG'." >&2
  exit 1
fi
echo "[4/5] Deploying Network settings under existing Network name '$NETWORK_NAME'..."
NETWORK_SRC_FILE="$(ls "$SRC_DEFAULT_DIR"/networks/*.network-meta.xml | head -n1)"
NETWORK_DIR="$TMP_DIR/network-only"
mkdir -p "$NETWORK_DIR/networks"
cp "$NETWORK_SRC_FILE" "$NETWORK_DIR/networks/$NETWORK_NAME.network-meta.xml"
cat >"$NETWORK_DIR/package.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>$NETWORK_NAME</members>
        <name>Network</name>
    </types>
    <version>66.0</version>
</Package>
EOF
sf project deploy start --metadata-dir "$NETWORK_DIR" --target-org "$ORG" --ignore-conflicts
echo ""

# --- [5/5] Deploy the bundle, config, and site ---------------------------
echo "[5/5] Deploying Experience Bundle, Config, and Site..."
MDAPI_DIR="$TMP_DIR/mdapi"
mkdir -p "$MDAPI_DIR"

if [[ -d "$SRC_DEFAULT_DIR/digitalExperienceConfigs" ]]; then
  cp -R "$SRC_DEFAULT_DIR/digitalExperienceConfigs" "$MDAPI_DIR/"
fi
mkdir -p "$MDAPI_DIR/sites"
cp -R "$SRC_DEFAULT_DIR/sites/." "$MDAPI_DIR/sites/"

shopt -s nullglob
bundle_members=()
for d in "$SRC_DEFAULT_DIR"/digitalExperiences/*; do
  [[ -d "$d" ]] || continue
  bundle_name="$(basename "$d")"
  # MDAPI requires the physical path to nest under the workspace type
  # (digitalExperiences/site/<bundleName>/...), unlike the flat source-format
  # layout (digitalExperiences/<bundleName>/...). All bundles here are "site"
  # workspaces (each has an sfdc_cms__site subfolder).
  mkdir -p "$MDAPI_DIR/digitalExperiences/site"
  cp -R "$d" "$MDAPI_DIR/digitalExperiences/site/$bundle_name"
  bundle_members+=("site/$bundle_name")
done

config_members=()
for f in "$SRC_DEFAULT_DIR"/digitalExperienceConfigs/*.digitalExperienceConfig; do
  [[ -f "$f" ]] || continue
  config_members+=("$(basename "$f" .digitalExperienceConfig)")
done
for f in "$SRC_DEFAULT_DIR"/digitalExperienceConfigs/*.digitalExperienceConfig-meta.xml; do
  [[ -f "$f" ]] || continue
  config_members+=("$(basename "$f" .digitalExperienceConfig-meta.xml)")
done

site_members=()
for f in "$SRC_DEFAULT_DIR"/sites/*.site-meta.xml; do
  [[ -f "$f" ]] || continue
  site_members+=("$(basename "$f" .site-meta.xml)")
done

shopt -u nullglob

if [[ ${#bundle_members[@]} -eq 0 && ${#config_members[@]} -eq 0 && ${#site_members[@]} -eq 0 ]]; then
  echo "Error: No Experience metadata found under $SRC_DEFAULT_DIR." >&2
  exit 1
fi

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<Package xmlns="http://soap.sforce.com/2006/04/metadata">'

  if [[ ${#bundle_members[@]} -gt 0 ]]; then
    echo '    <types>'
    for m in "${bundle_members[@]}"; do
      echo "        <members>$m</members>"
    done
    echo '        <name>DigitalExperienceBundle</name>'
    echo '    </types>'
  fi

  if [[ ${#config_members[@]} -gt 0 ]]; then
    echo '    <types>'
    for m in "${config_members[@]}"; do
      echo "        <members>$m</members>"
    done
    echo '        <name>DigitalExperienceConfig</name>'
    echo '    </types>'
  fi

  if [[ ${#site_members[@]} -gt 0 ]]; then
    echo '    <types>'
    for m in "${site_members[@]}"; do
      echo "        <members>$m</members>"
    done
    echo '        <name>CustomSite</name>'
    echo '    </types>'
  fi

  echo '    <version>66.0</version>'
  echo '</Package>'
} >"$MDAPI_DIR/package.xml"

sf project deploy start \
  --metadata-dir "$MDAPI_DIR" \
  --target-org "$ORG" \
  --ignore-conflicts

echo ""
echo "Deploy complete."
echo "Next: publish the Experience site in Experience Builder."
echo ""
