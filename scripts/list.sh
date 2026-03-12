#!/usr/bin/env bash
# skills-sync: list skills and plugins locally and/or remotely

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

PLUGINS_DIR="${HOME}/.claude/plugins"
INSTALLED_FILE="${PLUGINS_DIR}/installed_plugins.json"
MARKETPLACES_FILE="${PLUGINS_DIR}/known_marketplaces.json"
REMOTE_PLUGINS_DIR="plugins-config"

show_local() {
  echo "## Local Skills (${SKILLS_DIR})"
  echo ""

  local count=0
  for dir in "${SKILLS_DIR}"/*/; do
    [[ -d "${dir}" ]] || continue
    local name
    name=$(basename "${dir}")
    local desc=""
    if [[ -f "${dir}/SKILL.md" ]]; then
      desc=$(get_local_skill_info "${name}" 2>/dev/null || echo "")
    fi
    if [[ -n "${desc}" ]]; then
      echo "- **${name}**: ${desc}"
    else
      echo "- **${name}**"
    fi
    count=$((count + 1))
  done

  if [[ ${count} -eq 0 ]]; then
    echo "_No local skills found._"
  else
    echo ""
    echo "Total: ${count} skill(s)"
  fi
}

show_remote() {
  load_config || return 1

  echo "## Remote Skills (${REPO}/${REMOTE_SKILLS_DIR})"
  echo ""

  local skills
  skills=$(list_remote_skills 2>/dev/null)

  if [[ -z "${skills}" ]]; then
    echo "_No remote skills found._"
    return
  fi

  local count=0
  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    echo "- **${name}**"
    count=$((count + 1))
  done <<< "${skills}"

  echo ""
  echo "Total: ${count} skill(s)"
}

show_all() {
  load_config || return 1

  echo "## Skills Overview"
  echo ""
  echo "| Skill | Local | Remote | Status |"
  echo "|-------|-------|--------|--------|"

  # Collect all unique skill names
  local all_skills=()
  local local_skills=()
  local remote_skills=()

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    local_skills+=("${name}")
    all_skills+=("${name}")
  done <<< "$(list_local_skills)"

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    remote_skills+=("${name}")
    # Add if not already in list
    local found=0
    for s in "${all_skills[@]+"${all_skills[@]}"}"; do
      [[ "${s}" == "${name}" ]] && found=1 && break
    done
    [[ ${found} -eq 0 ]] && all_skills+=("${name}")
  done <<< "$(list_remote_skills 2>/dev/null)"

  # Sort and display
  local sorted
  sorted=$(printf '%s\n' "${all_skills[@]+"${all_skills[@]}"}" | sort -u)

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    local has_local="no"
    local has_remote="no"
    local status=""

    for s in "${local_skills[@]+"${local_skills[@]}"}"; do
      [[ "${s}" == "${name}" ]] && has_local="yes" && break
    done
    for s in "${remote_skills[@]+"${remote_skills[@]}"}"; do
      [[ "${s}" == "${name}" ]] && has_remote="yes" && break
    done

    if [[ "${has_local}" == "yes" && "${has_remote}" == "yes" ]]; then
      status="synced"
    elif [[ "${has_local}" == "yes" ]]; then
      status="local only"
    else
      status="remote only"
    fi

    local local_mark=$([[ "${has_local}" == "yes" ]] && echo "✓" || echo "—")
    local remote_mark=$([[ "${has_remote}" == "yes" ]] && echo "✓" || echo "—")

    echo "| ${name} | ${local_mark} | ${remote_mark} | ${status} |"
  done <<< "${sorted}"
}

show_plugins() {
  load_config || return 1

  echo "## Installed Plugins"
  echo ""

  # Local plugins
  local local_plugins=()
  if [[ -f "${INSTALLED_FILE}" ]]; then
    while IFS= read -r name; do
      [[ -n "${name}" ]] && local_plugins+=("${name}")
    done <<< "$(jq -r '.plugins | keys[]' "${INSTALLED_FILE}" 2>/dev/null)"
  fi

  # Remote plugins
  local remote_plugins=()
  local remote_installed
  remote_installed=$(gh api "/repos/${REPO}/contents/${REMOTE_PLUGINS_DIR}/installed_plugins.json" \
    -H "Accept: application/vnd.github.v3+json" \
    --jq '.content' 2>/dev/null | tr -d '\n' | base64_decode 2>/dev/null || echo "")

  if [[ -n "${remote_installed}" ]]; then
    while IFS= read -r name; do
      [[ -n "${name}" ]] && remote_plugins+=("${name}")
    done <<< "$(echo "${remote_installed}" | jq -r '.plugins | keys[]' 2>/dev/null)"
  fi

  # Collect all unique plugin names
  local all_plugins=()
  for p in "${local_plugins[@]+"${local_plugins[@]}"}"; do
    all_plugins+=("${p}")
  done
  for p in "${remote_plugins[@]+"${remote_plugins[@]}"}"; do
    local found=0
    for a in "${all_plugins[@]+"${all_plugins[@]}"}"; do
      [[ "${a}" == "${p}" ]] && found=1 && break
    done
    [[ ${found} -eq 0 ]] && all_plugins+=("${p}")
  done

  if [[ ${#all_plugins[@]} -eq 0 ]]; then
    echo "_No plugins found locally or remotely._"
    return
  fi

  echo "| Plugin | Local | Remote | Status |"
  echo "|--------|-------|--------|--------|"

  local sorted
  sorted=$(printf '%s\n' "${all_plugins[@]}" | sort -u)

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    local has_local="no"
    local has_remote="no"

    for p in "${local_plugins[@]+"${local_plugins[@]}"}"; do
      [[ "${p}" == "${name}" ]] && has_local="yes" && break
    done
    for p in "${remote_plugins[@]+"${remote_plugins[@]}"}"; do
      [[ "${p}" == "${name}" ]] && has_remote="yes" && break
    done

    local status=""
    if [[ "${has_local}" == "yes" && "${has_remote}" == "yes" ]]; then
      status="synced"
    elif [[ "${has_local}" == "yes" ]]; then
      status="local only"
    else
      status="remote only"
    fi

    local local_mark=$([[ "${has_local}" == "yes" ]] && echo "✓" || echo "—")
    local remote_mark=$([[ "${has_remote}" == "yes" ]] && echo "✓" || echo "—")

    echo "| ${name} | ${local_mark} | ${remote_mark} | ${status} |"
  done <<< "${sorted}"

  echo ""

  # Marketplaces
  echo "## Marketplaces"
  echo ""

  local local_markets=()
  if [[ -f "${MARKETPLACES_FILE}" ]]; then
    while IFS= read -r name; do
      [[ -n "${name}" ]] && local_markets+=("${name}")
    done <<< "$(jq -r 'keys[]' "${MARKETPLACES_FILE}" 2>/dev/null)"
  fi

  local remote_markets=()
  local remote_marketplaces
  remote_marketplaces=$(gh api "/repos/${REPO}/contents/${REMOTE_PLUGINS_DIR}/known_marketplaces.json" \
    -H "Accept: application/vnd.github.v3+json" \
    --jq '.content' 2>/dev/null | tr -d '\n' | base64_decode 2>/dev/null || echo "")

  if [[ -n "${remote_marketplaces}" ]]; then
    while IFS= read -r name; do
      [[ -n "${name}" ]] && remote_markets+=("${name}")
    done <<< "$(echo "${remote_marketplaces}" | jq -r 'keys[]' 2>/dev/null)"
  fi

  local all_markets=()
  for m in "${local_markets[@]+"${local_markets[@]}"}"; do
    all_markets+=("${m}")
  done
  for m in "${remote_markets[@]+"${remote_markets[@]}"}"; do
    local found=0
    for a in "${all_markets[@]+"${all_markets[@]}"}"; do
      [[ "${a}" == "${m}" ]] && found=1 && break
    done
    [[ ${found} -eq 0 ]] && all_markets+=("${m}")
  done

  if [[ ${#all_markets[@]} -eq 0 ]]; then
    echo "_No marketplaces found._"
    return
  fi

  echo "| Marketplace | Local | Remote | Source |"
  echo "|-------------|-------|--------|--------|"

  local sorted_m
  sorted_m=$(printf '%s\n' "${all_markets[@]}" | sort -u)

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    local has_local="no"
    local has_remote="no"
    local source="—"

    for m in "${local_markets[@]+"${local_markets[@]}"}"; do
      [[ "${m}" == "${name}" ]] && has_local="yes" && break
    done
    for m in "${remote_markets[@]+"${remote_markets[@]}"}"; do
      [[ "${m}" == "${name}" ]] && has_remote="yes" && break
    done

    if [[ "${has_local}" == "yes" && -f "${MARKETPLACES_FILE}" ]]; then
      source=$(jq -r --arg n "${name}" '.[$n].source.repo // .[$n].source.source // "—"' "${MARKETPLACES_FILE}" 2>/dev/null)
    elif [[ "${has_remote}" == "yes" && -n "${remote_marketplaces}" ]]; then
      source=$(echo "${remote_marketplaces}" | jq -r --arg n "${name}" '.[$n].source.repo // .[$n].source.source // "—"' 2>/dev/null)
    fi

    local local_mark=$([[ "${has_local}" == "yes" ]] && echo "✓" || echo "—")
    local remote_mark=$([[ "${has_remote}" == "yes" ]] && echo "✓" || echo "—")

    echo "| ${name} | ${local_mark} | ${remote_mark} | ${source} |"
  done <<< "${sorted_m}"
}

# --- Main ---

mode="${1:-all}"

case "${mode}" in
  local)
    show_local
    ;;
  remote)
    show_remote
    ;;
  skills)
    show_all
    ;;
  plugins)
    show_plugins
    ;;
  all)
    show_all
    echo ""
    show_plugins
    ;;
  *)
    echo "Usage: list.sh [all|skills|plugins|local|remote]"
    exit 1
    ;;
esac
