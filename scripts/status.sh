#!/usr/bin/env bash
# skills-sync: show configuration and sync status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

main() {
  echo "## Skills-Sync Status"
  echo ""

  # Config
  echo "### Configuration"
  if [[ -f "${CONFIG_FILE}" ]]; then
    load_config
    echo "- Config file: \`${CONFIG_FILE}\`"
    echo "- Repository: \`${REPO}\`"
    echo "- Branch: \`${BRANCH}\`"
    echo "- Remote directory: \`${REMOTE_SKILLS_DIR}\`"
  else
    echo "- **Not configured.** Run \`/skills-sync:setup\` first."
    return
  fi
  echo ""

  # gh auth
  echo "### GitHub CLI"
  if command -v gh &>/dev/null; then
    echo "- gh CLI: installed ($(gh --version | head -1))"
    if gh auth status &>/dev/null; then
      local gh_user
      gh_user=$(gh api /user --jq '.login' 2>/dev/null || echo "unknown")
      echo "- Authenticated as: \`${gh_user}\`"
    else
      echo "- **Not authenticated.** Run \`gh auth login\`."
    fi
  else
    echo "- **gh CLI not installed.** Install from https://cli.github.com/"
  fi
  echo ""

  # Skills counts
  echo "### Skills"
  local local_count=0
  local remote_count=0

  while IFS= read -r name; do
    [[ -n "${name}" ]] && local_count=$((local_count + 1))
  done <<< "$(list_local_skills)"

  while IFS= read -r name; do
    [[ -n "${name}" ]] && remote_count=$((remote_count + 1))
  done <<< "$(list_remote_skills 2>/dev/null)"

  echo "- Local skills: ${local_count}"
  echo "- Remote skills: ${remote_count}"
  echo ""

  # Last sync times
  echo "### Last Sync Times"
  local state
  state=$(load_state)
  local has_syncs=false

  local skill_names
  skill_names=$(echo "${state}" | jq -r '.skills // {} | keys[]' 2>/dev/null || true)

  if [[ -n "${skill_names}" ]]; then
    while IFS= read -r name; do
      [[ -n "${name}" ]] || continue
      local ts
      ts=$(echo "${state}" | jq -r --arg n "${name}" '.skills[$n].last_synced // "unknown"')
      echo "- ${name}: ${ts}"
      has_syncs=true
    done <<< "${skill_names}"
  fi

  if [[ "${has_syncs}" == "false" ]]; then
    echo "_No sync history yet._"
  fi
}

main
