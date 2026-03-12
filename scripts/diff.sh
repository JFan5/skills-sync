#!/usr/bin/env bash
# skills-sync: diff local vs remote skills

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

diff_skill() {
  local skill_name="$1"
  local skill_dir="${SKILLS_DIR}/${skill_name}"

  echo "## Diff: ${skill_name}"
  echo ""

  local has_local=false
  local has_remote=false

  [[ -d "${skill_dir}" ]] && has_local=true

  load_config || return 1

  # Check remote existence
  local remote_files
  remote_files=$(list_remote_skill_files "${skill_name}" 2>/dev/null || true)
  [[ -n "${remote_files}" ]] && has_remote=true

  if [[ "${has_local}" == "false" && "${has_remote}" == "false" ]]; then
    echo "Skill '${skill_name}' not found locally or remotely."
    return 1
  fi

  if [[ "${has_local}" == "true" && "${has_remote}" == "false" ]]; then
    echo "Skill exists only locally. Use \`/skills-sync:push ${skill_name}\` to upload."
    return
  fi

  if [[ "${has_local}" == "false" && "${has_remote}" == "true" ]]; then
    echo "Skill exists only remotely. Use \`/skills-sync:pull ${skill_name}\` to download."
    return
  fi

  # Both exist -- diff each file
  local any_diff=false

  # Diff local files
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    local local_path="${skill_dir}/${file}"

    if is_binary_file "${local_path}"; then
      echo "Binary file: ${file} (skipping diff)"
      continue
    fi

    local remote_content
    remote_content=$(get_remote_file "${skill_name}/${file}" 2>/dev/null || echo "")

    if [[ -z "${remote_content}" ]]; then
      echo "### ${file} (local only)"
      echo "\`\`\`"
      cat "${local_path}"
      echo "\`\`\`"
      any_diff=true
      continue
    fi

    local local_content
    local_content=$(cat "${local_path}")

    if [[ "${local_content}" != "${remote_content}" ]]; then
      echo "### ${file}"
      echo "\`\`\`diff"
      diff --unified \
        <(echo "${remote_content}") \
        <(echo "${local_content}") \
        || true  # diff returns 1 when files differ
      echo "\`\`\`"
      any_diff=true
    fi
  done <<< "$(list_skill_files "${skill_name}" 2>/dev/null)"

  # Check for remote-only files
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    if [[ ! -f "${skill_dir}/${file}" ]]; then
      echo "### ${file} (remote only)"
      echo "\`\`\`"
      get_remote_file "${skill_name}/${file}" 2>/dev/null || true
      echo "\`\`\`"
      any_diff=true
    fi
  done <<< "${remote_files}"

  if [[ "${any_diff}" == "false" ]]; then
    echo "✓ Local and remote are identical."
  fi
}

diff_all() {
  local all_skills=()

  while IFS= read -r name; do
    [[ -n "${name}" ]] && all_skills+=("${name}")
  done <<< "$(list_local_skills)"

  load_config || return 1

  while IFS= read -r name; do
    [[ -n "${name}" ]] || continue
    local found=0
    for s in "${all_skills[@]+"${all_skills[@]}"}"; do
      [[ "${s}" == "${name}" ]] && found=1 && break
    done
    [[ ${found} -eq 0 ]] && all_skills+=("${name}")
  done <<< "$(list_remote_skills 2>/dev/null)"

  if [[ ${#all_skills[@]} -eq 0 ]]; then
    echo "No skills found locally or remotely."
    return
  fi

  for name in "${all_skills[@]}"; do
    diff_skill "${name}"
    echo ""
  done
}

# --- Main ---

if [[ $# -gt 0 && "$1" != "--all" ]]; then
  diff_skill "$1"
else
  diff_all
fi
