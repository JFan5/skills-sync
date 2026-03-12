#!/usr/bin/env bash
# skills-sync: pull plugin configuration from GitHub and reinstall

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

PLUGINS_DIR="${HOME}/.claude/plugins"
INSTALLED_FILE="${PLUGINS_DIR}/installed_plugins.json"
MARKETPLACES_FILE="${PLUGINS_DIR}/known_marketplaces.json"
REMOTE_PLUGINS_DIR="plugins-config"

fetch_remote_json() {
  local filename="$1"
  gh api "/repos/${REPO}/contents/${REMOTE_PLUGINS_DIR}/${filename}" \
    -H "Accept: application/vnd.github.v3+json" \
    --jq '.content' 2>/dev/null | tr -d '\n' | base64_decode
}

main() {
  check_gh
  load_config

  echo "## Pulling Plugin Configuration"
  echo ""

  mkdir -p "${PLUGINS_DIR}"

  # Pull known_marketplaces.json first (needed to add marketplaces before installing)
  echo "Fetching marketplace sources..."
  local remote_marketplaces
  remote_marketplaces=$(fetch_remote_json "known_marketplaces.json" 2>/dev/null || echo "")

  if [[ -n "${remote_marketplaces}" ]]; then
    echo "  ✓ Found remote marketplace configuration"

    # Show what marketplaces will be added
    echo ""
    echo "### Marketplaces to restore:"
    echo "${remote_marketplaces}" | jq -r 'to_entries[] | "  - \(.key): \(.value.source.repo // .value.source.source // "unknown")"' 2>/dev/null

    echo ""
    echo "To add these marketplaces, run the following commands in Claude Code:"
    echo ""
    echo "${remote_marketplaces}" | jq -r 'to_entries[] | .value.source |
      if .source == "github" then "  /plugin marketplace add \(.repo)"
      else "  /plugin marketplace add \(.source // "unknown")"
      end' 2>/dev/null
  else
    echo "  — No remote marketplace configuration found"
  fi

  echo ""

  # Pull installed_plugins.json
  echo "Fetching installed plugins list..."
  local remote_installed
  remote_installed=$(fetch_remote_json "installed_plugins.json" 2>/dev/null || echo "")

  if [[ -n "${remote_installed}" ]]; then
    echo "  ✓ Found remote plugin list"

    echo ""
    echo "### Plugins to install:"
    echo "${remote_installed}" | jq -r '.plugins | keys[]' 2>/dev/null | while read -r name; do
      echo "  - ${name}"
    done

    echo ""
    echo "To install these plugins, run the following commands in Claude Code:"
    echo ""
    echo "${remote_installed}" | jq -r '.plugins | keys[]' 2>/dev/null | while read -r name; do
      echo "  /plugin install ${name}"
    done
  else
    echo "  — No remote plugin list found"
  fi

  echo ""
  echo "---"
  echo ""
  echo "**Note:** Plugin installation requires Claude Code's built-in /plugin command."
  echo "Copy and run the commands above in Claude Code to restore your plugins."
}

main "$@"
