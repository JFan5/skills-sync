#!/usr/bin/env bash
# skills-sync: self-update by reinstalling from GitHub

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

PLUGINS_DIR="${HOME}/.claude/plugins"
CACHE_DIR="${PLUGINS_DIR}/cache/skills-sync"

main() {
  check_gh

  echo "## Updating skills-sync plugin"
  echo ""

  # Show current version
  local current_version="unknown"
  local plugin_json="${CACHE_DIR}/skills-sync/1.0.0/.claude-plugin/plugin.json"
  if [[ -f "${plugin_json}" ]]; then
    current_version=$(jq -r '.version // "unknown"' "${plugin_json}" 2>/dev/null)
  fi
  echo "Current version: ${current_version}"

  # Remove cached plugin
  if [[ -d "${CACHE_DIR}" ]]; then
    echo "Clearing plugin cache..."
    rm -rf "${CACHE_DIR}"
    echo "  ✓ Cache cleared"
  fi

  # Remove from installed_plugins.json
  local installed_file="${PLUGINS_DIR}/installed_plugins.json"
  if [[ -f "${installed_file}" ]]; then
    local updated
    updated=$(jq 'del(.plugins["skills-sync@skills-sync"])' "${installed_file}" 2>/dev/null)
    if [[ -n "${updated}" ]]; then
      echo "${updated}" > "${installed_file}"
      echo "  ✓ Removed from installed plugins list"
    fi
  fi

  echo ""
  echo "✓ Plugin cache cleared. To complete the update, run in Claude Code:"
  echo ""
  echo "  /plugin install skills-sync@skills-sync"
  echo ""
  echo "Then restart Claude Code."
}

main "$@"
