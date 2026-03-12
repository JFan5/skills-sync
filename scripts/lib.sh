#!/usr/bin/env bash
# skills-sync shared library
# Sourced by all scripts -- provides config, gh wrappers, and utilities

set -euo pipefail

CONFIG_FILE="${HOME}/.claude/skills-sync.json"
STATE_FILE="${HOME}/.claude/skills-sync-state.json"
SKILLS_DIR="${HOME}/.claude/skills"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Platform Detection ---

detect_base64_flags() {
  # macOS base64 uses -D for decode, Linux uses -d
  # macOS base64 doesn't support -w0, Linux does
  if [[ "$(uname -s)" == "Darwin" ]]; then
    BASE64_DECODE_FLAG="-D"
    BASE64_ENCODE_CMD="base64"
  else
    BASE64_DECODE_FLAG="-d"
    BASE64_ENCODE_CMD="base64 -w0"
  fi
}

detect_base64_flags

base64_encode() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    base64 < "$1"
  else
    base64 -w0 < "$1"
  fi
}

base64_decode() {
  base64 ${BASE64_DECODE_FLAG}
}

# --- Config Management ---

load_config() {
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: Not configured. Run /skills-sync:setup first." >&2
    return 1
  fi

  REPO=$(jq -r '.repo // empty' "${CONFIG_FILE}" 2>/dev/null)
  BRANCH=$(jq -r '.branch // "main"' "${CONFIG_FILE}" 2>/dev/null)
  REMOTE_SKILLS_DIR=$(jq -r '.skills_dir // "skills"' "${CONFIG_FILE}" 2>/dev/null)

  if [[ -z "${REPO}" ]]; then
    echo "ERROR: No repo configured in ${CONFIG_FILE}. Run /skills-sync:setup first." >&2
    return 1
  fi
}

save_config() {
  local repo="$1"
  local branch="${2:-main}"
  local skills_dir="${3:-skills}"

  mkdir -p "$(dirname "${CONFIG_FILE}")"
  cat > "${CONFIG_FILE}" <<EOF
{
  "repo": "${repo}",
  "branch": "${branch}",
  "skills_dir": "${skills_dir}"
}
EOF
}

# --- State Management ---

load_state() {
  if [[ -f "${STATE_FILE}" ]]; then
    cat "${STATE_FILE}"
  else
    echo '{}'
  fi
}

save_state() {
  local state="$1"
  echo "${state}" > "${STATE_FILE}"
}

update_sync_time() {
  local skill_name="$1"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local state
  state=$(load_state)
  state=$(echo "${state}" | jq --arg name "${skill_name}" --arg ts "${timestamp}" \
    '.skills[$name].last_synced = $ts')
  save_state "${state}"
}

get_last_sync() {
  local skill_name="$1"
  load_state | jq -r --arg name "${skill_name}" '.skills[$name].last_synced // "never"'
}

# --- gh CLI Checks ---

check_gh() {
  if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI not found. Install from https://cli.github.com/" >&2
    return 1
  fi

  if ! gh auth status &>/dev/null; then
    echo "ERROR: gh CLI not authenticated. Run 'gh auth login' first." >&2
    return 1
  fi
}

# --- Local Skills ---

list_local_skills() {
  if [[ ! -d "${SKILLS_DIR}" ]]; then
    return
  fi

  for dir in "${SKILLS_DIR}"/*/; do
    [[ -d "${dir}" ]] || continue
    local name
    name=$(basename "${dir}")
    echo "${name}"
  done
}

get_local_skill_info() {
  local skill_name="$1"
  local skill_dir="${SKILLS_DIR}/${skill_name}"
  local skill_file="${skill_dir}/SKILL.md"

  if [[ ! -f "${skill_file}" ]]; then
    return 1
  fi

  # Extract frontmatter description if present
  if head -1 "${skill_file}" | grep -q '^---$'; then
    sed -n '/^---$/,/^---$/p' "${skill_file}" | grep -i 'description:' | sed 's/^[^:]*: *//' || echo ""
  fi
}

# --- Remote Skills (GitHub API) ---

list_remote_skills() {
  load_config || return 1
  gh api "/repos/${REPO}/contents/${REMOTE_SKILLS_DIR}" \
    --jq '.[] | select(.type == "dir") | .name' 2>/dev/null || true
}

get_remote_file() {
  local path="$1"
  load_config || return 1
  gh api "/repos/${REPO}/contents/${REMOTE_SKILLS_DIR}/${path}" \
    -H "Accept: application/vnd.github.v3+json" \
    --jq '.content' 2>/dev/null | tr -d '\n' | base64_decode
}

get_remote_file_sha() {
  local path="$1"
  load_config || return 1
  gh api "/repos/${REPO}/contents/${REMOTE_SKILLS_DIR}/${path}" \
    --jq '.sha' 2>/dev/null || echo ""
}

put_remote_file() {
  local remote_path="$1"
  local local_file="$2"
  local commit_msg="${3:-Update ${remote_path}}"

  load_config || return 1

  local content
  content=$(base64_encode "${local_file}")

  local sha
  sha=$(get_remote_file_sha "${remote_path}")

  local args=()
  args+=(-X PUT "/repos/${REPO}/contents/${REMOTE_SKILLS_DIR}/${remote_path}")
  args+=(-f "message=${commit_msg}")
  args+=(-f "content=${content}")
  args+=(-f "branch=${BRANCH}")
  if [[ -n "${sha}" ]]; then
    args+=(-f "sha=${sha}")
  fi

  gh api "${args[@]}" --silent
}

delete_remote_file() {
  local remote_path="$1"
  local commit_msg="${2:-Delete ${remote_path}}"

  load_config || return 1

  local sha
  sha=$(get_remote_file_sha "${remote_path}")

  if [[ -z "${sha}" ]]; then
    echo "ERROR: Remote file not found: ${remote_path}" >&2
    return 1
  fi

  gh api -X DELETE "/repos/${REPO}/contents/${REMOTE_SKILLS_DIR}/${remote_path}" \
    -f "message=${commit_msg}" \
    -f "sha=${sha}" \
    -f "branch=${BRANCH}" --silent
}

# --- Utility ---

list_skill_files() {
  # List all files in a local skill directory, relative to the skill dir
  local skill_name="$1"
  local skill_dir="${SKILLS_DIR}/${skill_name}"

  if [[ ! -d "${skill_dir}" ]]; then
    return 1
  fi

  find "${skill_dir}" -type f | sed "s|^${skill_dir}/||" | sort
}

list_remote_skill_files() {
  # List all files in a remote skill directory
  local skill_name="$1"
  load_config || return 1

  gh api "/repos/${REPO}/contents/${REMOTE_SKILLS_DIR}/${skill_name}" \
    --jq '.[].name' 2>/dev/null || \
  gh api "/repos/${REPO}/contents/${REMOTE_SKILLS_DIR}/${skill_name}" \
    --jq '.name' 2>/dev/null || true
}

checksum_file() {
  sha256sum "$1" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
}

checksum_string() {
  echo -n "$1" | sha256sum 2>/dev/null | cut -d' ' -f1 || echo -n "$1" | shasum -a 256 2>/dev/null | cut -d' ' -f1
}

is_binary_file() {
  file --mime-encoding "$1" 2>/dev/null | grep -q 'binary'
}
