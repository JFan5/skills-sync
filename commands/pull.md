---
name: pull
description: Pull skills from GitHub to local machine
arguments:
  - name: skill-name
    description: "Name of skill to pull, or --all for everything"
    required: false
  - name: --force
    description: "Overwrite local files without conflict prompts"
    required: false
---

Pull Claude Code skills from the configured GitHub repository to the local machine.

If no skill name is provided, list available remote skills and ask the user which ones to pull using AskUserQuestion with multiSelect.

If a skill name or --all is provided, run the pull script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/pull.sh" $ARGUMENTS
```

If there are conflicts (local and remote differ), show the diff and ask the user to choose:
- **Keep local**: skip this file
- **Keep remote**: overwrite local with remote version
- **Skip**: don't touch this skill

Report the results: how many files were pulled, skipped, or had conflicts.
