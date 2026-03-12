---
name: push
description: Push local skills to GitHub
arguments:
  - name: skill-name
    description: "Name of skill to push, or --all for everything"
    required: false
---

Push local Claude Code skills to the configured GitHub repository.

If no skill name is provided, list available skills and ask the user which ones to push using AskUserQuestion with multiSelect.

If a skill name or --all is provided, run the push script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/push.sh" $ARGUMENTS
```

Before pushing, if a skill has diverged from remote, show the diff and confirm with the user before overwriting.

Report the results: how many files were pushed, skipped, or had conflicts.
