#!/usr/bin/env bash
# skills-sync: push installed plugins list to GitHub

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

PLUGINS_DIR="${HOME}/.claude/plugins"
INSTALLED_FILE="${PLUGINS_DIR}/installed_plugins.json"
MARKETPLACES_FILE="${PLUGINS_DIR}/known_marketplaces.json"
REMOTE_PLUGINS_DIR="plugins-config"

main() {
  check_gh
  load_config

  echo "## Pushing Plugin Configuration"
  echo ""

  local files_pushed=0

  # Push installed_plugins.json
  if [[ -f "${INSTALLED_FILE}" ]]; then
    echo "Uploading installed plugins list..."
    local content
    content=$(cat "${INSTALLED_FILE}")
    local encoded
    if [[ "$(uname -s)" == "Darwin" ]]; then
      encoded=$(echo -n "${content}" | base64)
    else
      encoded=$(echo -n "${content}" | base64 -w0)
    fi

    local sha
    sha=$(gh api "/repos/${REPO}/contents/${REMOTE_PLUGINS_DIR}/installed_plugins.json" \
      --jq '.sha' 2>/dev/null || echo "")

    local args=(-X PUT "/repos/${REPO}/contents/${REMOTE_PLUGINS_DIR}/installed_plugins.json")
    args+=(-f "message=Sync installed plugins list")
    args+=(-f "content=${encoded}")
    args+=(-f "branch=${BRANCH}")
    [[ -n "${sha}" ]] && args+=(-f "sha=${sha}")

    gh api "${args[@]}" --silent
    echo "  ✓ installed_plugins.json"
    files_pushed=$((files_pushed + 1))
  else
    echo "  — No installed_plugins.json found"
  fi

  # Push known_marketplaces.json
  if [[ -f "${MARKETPLACES_FILE}" ]]; then
    echo "Uploading marketplace sources..."
    local content
    content=$(cat "${MARKETPLACES_FILE}")
    local encoded
    if [[ "$(uname -s)" == "Darwin" ]]; then
      encoded=$(echo -n "${content}" | base64)
    else
      encoded=$(echo -n "${content}" | base64 -w0)
    fi

    local sha
    sha=$(gh api "/repos/${REPO}/contents/${REMOTE_PLUGINS_DIR}/known_marketplaces.json" \
      --jq '.sha' 2>/dev/null || echo "")

    local args=(-X PUT "/repos/${REPO}/contents/${REMOTE_PLUGINS_DIR}/known_marketplaces.json")
    args+=(-f "message=Sync known marketplaces list")
    args+=(-f "content=${encoded}")
    args+=(-f "branch=${BRANCH}")
    [[ -n "${sha}" ]] && args+=(-f "sha=${sha}")

    gh api "${args[@]}" --silent
    echo "  ✓ known_marketplaces.json"
    files_pushed=$((files_pushed + 1))
  else
    echo "  — No known_marketplaces.json found"
  fi

  echo ""
  echo "Done: ${files_pushed} file(s) pushed."

  # Show summary
  if [[ -f "${INSTALLED_FILE}" ]]; then
    echo ""
    echo "### Installed Plugins"
    jq -r '.plugins | keys[]' "${INSTALLED_FILE}" 2>/dev/null | while read -r name; do
      echo "  - ${name}"
    done
  fi

  if [[ -f "${MARKETPLACES_FILE}" ]]; then
    echo ""
    echo "### Marketplaces"
    jq -r 'keys[]' "${MARKETPLACES_FILE}" 2>/dev/null | while read -r name; do
      local source
      source=$(jq -r --arg n "${name}" '.[$n].source.repo // .[$n].source.source // "unknown"' "${MARKETPLACES_FILE}")
      echo "  - ${name} (${source})"
    done
  fi
}

main "$@"
