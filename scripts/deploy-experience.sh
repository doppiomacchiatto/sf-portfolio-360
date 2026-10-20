#!/usr/bin/env bash
# deploy-experience.sh — Deploy Experience Cloud metadata from experiences/
# Usage: ./scripts/deploy-experience.sh [org-alias]
#   org-alias defaults to "tsx"

set -euo pipefail

ORG="${1:-pm-scratch}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$ROOT_DIR/experiences"
SRC_DEFAULT_DIR="$SRC_DIR/main/default"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "Error: Source directory not found: $SRC_DIR" >&2
  exit 1
fi

echo ""
echo "========================================"
echo "  PM Portfolio 360 — Experience Deploy"
echo "  Target org : $ORG"
echo "  Source dir : $SRC_DIR"
echo "  Deploy mode: Metadata API package"
echo "========================================"
echo ""

TMP_DIR="$(mktemp -d)"
MDAPI_DIR="$TMP_DIR/mdapi"
mkdir -p "$MDAPI_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! -d "$SRC_DEFAULT_DIR" ]]; then
  echo "Error: Expected source directory missing: $SRC_DEFAULT_DIR" >&2
  exit 1
fi

if [[ -d "$SRC_DEFAULT_DIR/digitalExperienceConfigs" ]]; then
  cp -R "$SRC_DEFAULT_DIR/digitalExperienceConfigs" "$MDAPI_DIR/"
fi

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

shopt -u nullglob

if [[ ${#bundle_members[@]} -eq 0 && ${#config_members[@]} -eq 0 ]]; then
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

  echo '    <version>66.0</version>'
  echo '</Package>'
} > "$MDAPI_DIR/package.xml"

sf project deploy start \
  --metadata-dir "$MDAPI_DIR" \
  --target-org "$ORG" \
  --ignore-conflicts

echo ""
echo "Deploy complete."
echo "Next: publish the Experience site in Experience Builder."
echo ""
