#!/usr/bin/env bash
# skills-sync: push local skills to GitHub

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

push_skill() {
  local skill_name="$1"
  local skill_dir="${SKILLS_DIR}/${skill_name}"

  if [[ ! -d "${skill_dir}" ]]; then
    echo "ERROR: Local skill '${skill_name}' not found at ${skill_dir}" >&2
    return 1
  fi

  load_config || return 1

  echo "Pushing skill: ${skill_name}"

  local files_pushed=0
  local files_skipped=0

  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    local local_path="${skill_dir}/${file}"
    local remote_path="${skill_name}/${file}"

    # Check if remote file exists and compare
    local remote_content
    remote_content=$(get_remote_file "${remote_path}" 2>/dev/null || echo "")

    if [[ -n "${remote_content}" ]]; then
      local local_content
      local_content=$(cat "${local_path}")

      if [[ "${local_content}" == "${remote_content}" ]]; then
        echo "  ✓ ${file} (unchanged, skipping)"
        files_skipped=$((files_skipped + 1))
        continue
      fi

      echo "  ↑ ${file} (updating)"
    else
      echo "  + ${file} (new)"
    fi

    put_remote_file "${remote_path}" "${local_path}" "Sync ${skill_name}/${file} via skills-sync"
    files_pushed=$((files_pushed + 1))
  done <<< "$(list_skill_files "${skill_name}")"

  update_sync_time "${skill_name}"

  echo ""
  echo "Done: ${files_pushed} file(s) pushed, ${files_skipped} unchanged."
}

push_all() {
  local skills=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && skills+=("${name}")
  done <<< "$(list_local_skills)"

  if [[ ${#skills[@]} -eq 0 ]]; then
    echo "No local skills found in ${SKILLS_DIR}"
    return
  fi

  echo "Pushing all local skills (${#skills[@]})..."
  echo ""

  for skill in "${skills[@]}"; do
    push_skill "${skill}"
    echo ""
  done
}

# --- Main ---

check_gh
load_config

if [[ $# -eq 0 ]]; then
  # No argument -- list skills for selection
  echo "## Local Skills"
  echo ""
  list_local_skills
  echo ""
  echo "Specify a skill name to push, or use --all to push everything."
  echo "Usage: push [skill-name|--all]"
  exit 0
fi

if [[ "$1" == "--all" ]]; then
  push_all
else
  push_skill "$1"
fi
