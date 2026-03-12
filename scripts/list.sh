#!/usr/bin/env bash
# skills-sync: list skills locally and/or remotely

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

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

# --- Main ---

mode="${1:-all}"

case "${mode}" in
  local)
    show_local
    ;;
  remote)
    show_remote
    ;;
  all)
    show_all
    ;;
  *)
    echo "Usage: list.sh [local|remote|all]"
    exit 1
    ;;
esac
