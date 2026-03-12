#!/usr/bin/env bash
# skills-sync: setup script
# Configures GitHub repo for skills syncing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

main() {
  echo "=== Skills-Sync Setup ==="
  echo ""

  # Check gh CLI
  echo "Checking prerequisites..."
  check_gh
  echo "✓ gh CLI installed and authenticated"
  echo ""

  # Get GitHub username
  local gh_user
  gh_user=$(gh api /user --jq '.login')
  echo "Logged in as: ${gh_user}"
  echo ""

  # Get repo name from argument or use default
  local repo_name="${1:-claude-skills}"
  local full_repo="${gh_user}/${repo_name}"

  echo "Repository: ${full_repo}"

  # Check if repo exists
  if gh repo view "${full_repo}" &>/dev/null; then
    echo "✓ Repository already exists"
  else
    echo "Creating private repository: ${full_repo}"
    gh repo create "${full_repo}" --private --description "Claude Code skills synced via skills-sync" || {
      echo "ERROR: Failed to create repository" >&2
      exit 1
    }
    echo "✓ Repository created"

    # Initialize with a README so the contents API works
    echo "Initializing repository..."
    local readme_content
    if [[ "$(uname -s)" == "Darwin" ]]; then
      readme_content=$(printf "# Claude Skills\n\nSynced via [skills-sync](https://github.com/JFan5/skills-sync).\n" | base64)
    else
      readme_content=$(printf "# Claude Skills\n\nSynced via [skills-sync](https://github.com/JFan5/skills-sync).\n" | base64 -w0)
    fi
    gh api -X PUT "/repos/${full_repo}/contents/README.md" \
      -f message="Initial commit" \
      -f content="${readme_content}" \
      -f branch="main" --silent 2>/dev/null || true
    echo "✓ Repository initialized"
  fi

  # Get branch (default: main)
  local branch="${2:-main}"

  # Get remote skills directory (default: skills)
  local skills_dir="${3:-skills}"

  # Save config
  save_config "${full_repo}" "${branch}" "${skills_dir}"
  echo ""
  echo "✓ Configuration saved to ${CONFIG_FILE}"
  echo ""

  # Initialize state file
  if [[ ! -f "${STATE_FILE}" ]]; then
    echo '{"skills":{}}' > "${STATE_FILE}"
    echo "✓ State file initialized"
  fi

  # Verify connection
  echo ""
  echo "Verifying connection..."
  if gh api "/repos/${full_repo}" --jq '.full_name' &>/dev/null; then
    echo "✓ Connection verified"
  else
    echo "WARNING: Could not verify repository access" >&2
  fi

  echo ""
  echo "Setup complete! Available commands:"
  echo "  /skills-sync:list    - List local and remote skills"
  echo "  /skills-sync:status  - Show sync status"
  echo "  /skills-sync:push    - Push skills to GitHub"
  echo "  /skills-sync:pull    - Pull skills from GitHub"
  echo "  /skills-sync:diff    - Compare local vs remote"
}

main "$@"
