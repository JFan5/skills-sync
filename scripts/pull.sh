#!/usr/bin/env bash
# skills-sync: pull skills from GitHub to local

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

pull_skill() {
  local skill_name="$1"
  local skill_dir="${SKILLS_DIR}/${skill_name}"
  local force="${2:-false}"

  load_config || return 1

  echo "Pulling skill: ${skill_name}"

  # Get remote files
  local remote_files
  remote_files=$(list_remote_skill_files "${skill_name}" 2>/dev/null || true)

  if [[ -z "${remote_files}" ]]; then
    echo "ERROR: Remote skill '${skill_name}' not found in ${REPO}/${REMOTE_SKILLS_DIR}" >&2
    return 1
  fi

  # Create local directory if needed
  mkdir -p "${skill_dir}"

  local files_pulled=0
  local files_skipped=0
  local files_conflict=0

  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    local local_path="${skill_dir}/${file}"
    local remote_path="${skill_name}/${file}"

    # Get remote content
    local remote_content
    remote_content=$(get_remote_file "${remote_path}" 2>/dev/null || echo "")

    if [[ -z "${remote_content}" ]]; then
      echo "  ! ${file} (failed to fetch, skipping)"
      continue
    fi

    if [[ -f "${local_path}" ]]; then
      local local_content
      local_content=$(cat "${local_path}")

      if [[ "${local_content}" == "${remote_content}" ]]; then
        echo "  ✓ ${file} (unchanged, skipping)"
        files_skipped=$((files_skipped + 1))
        continue
      fi

      if [[ "${force}" != "true" ]]; then
        echo "  ⚠ ${file} (CONFLICT - local and remote differ)"
        echo ""
        echo "--- Local ---"
        head -5 "${local_path}"
        echo "..."
        echo ""
        echo "--- Remote ---"
        echo "${remote_content}" | head -5
        echo "..."
        echo ""
        echo "CONFLICT: ${file} has local changes that differ from remote."
        echo "Options: Use --force to overwrite local, or run /skills-sync:diff ${skill_name} to see full diff."
        files_conflict=$((files_conflict + 1))
        continue
      fi

      echo "  ↓ ${file} (overwriting local)"
    else
      echo "  + ${file} (new)"
    fi

    # Ensure parent directory exists
    mkdir -p "$(dirname "${local_path}")"
    echo "${remote_content}" > "${local_path}"
    files_pulled=$((files_pulled + 1))
  done <<< "${remote_files}"

  if [[ ${files_pulled} -gt 0 ]]; then
    update_sync_time "${skill_name}"
  fi

  echo ""
  echo "Done: ${files_pulled} file(s) pulled, ${files_skipped} unchanged, ${files_conflict} conflict(s)."
}

pull_all() {
  local force="${1:-false}"

  load_config || return 1

  local skills=()
  while IFS= read -r name; do
    [[ -n "${name}" ]] && skills+=("${name}")
  done <<< "$(list_remote_skills 2>/dev/null)"

  if [[ ${#skills[@]} -eq 0 ]]; then
    echo "No remote skills found in ${REPO}/${REMOTE_SKILLS_DIR}"
    return
  fi

  echo "Pulling all remote skills (${#skills[@]})..."
  echo ""

  for skill in "${skills[@]}"; do
    pull_skill "${skill}" "${force}"
    echo ""
  done
}

# --- Main ---

check_gh
load_config

force=false
skill_name=""

for arg in "$@"; do
  case "${arg}" in
    --force)
      force=true
      ;;
    --all)
      skill_name="--all"
      ;;
    *)
      skill_name="${arg}"
      ;;
  esac
done

if [[ -z "${skill_name}" ]]; then
  echo "## Remote Skills"
  echo ""
  list_remote_skills 2>/dev/null
  echo ""
  echo "Specify a skill name to pull, or use --all to pull everything."
  echo "Usage: pull [skill-name|--all] [--force]"
  exit 0
fi

if [[ "${skill_name}" == "--all" ]]; then
  pull_all "${force}"
else
  pull_skill "${skill_name}" "${force}"
fi
