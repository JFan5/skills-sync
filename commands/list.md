---
name: list
description: List local and/or remote skills
arguments:
  - name: scope
    description: "Scope to list: local, remote, or all (default: all)"
    required: false
---

List Claude Code skills, comparing what's available locally vs remotely on GitHub.

Run the list script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/list.sh" $ARGUMENTS
```

Present the output as a formatted table to the user.
