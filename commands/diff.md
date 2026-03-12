---
name: diff
description: Compare local skills with remote versions on GitHub
arguments:
  - name: skill-name
    description: "Name of skill to diff (omit for all skills)"
    required: false
---

Compare local skills against their remote versions on GitHub, showing a unified diff of any differences.

Run the diff script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/diff.sh" $ARGUMENTS
```

Present the diff output to the user. If there are differences, suggest whether to push or pull to resolve them.
