---
name: setup
description: Configure GitHub repository for skills syncing
arguments:
  - name: repo-name
    description: "Name for the GitHub repo (default: claude-skills)"
    required: false
---

Set up skills-sync by configuring a GitHub repository for storing your Claude Code skills.

Run the setup script to check prerequisites, create or connect a repo, and save configuration:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh" $ARGUMENTS
```

After running, confirm the output to the user and explain what commands are now available.
