---
name: update
description: Update skills-sync plugin to the latest version
---

Update the skills-sync plugin to the latest version from GitHub.

Run the update script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/update.sh"
```

After the script completes, run the `/plugin install skills-sync@skills-sync` command shown in the output, then restart Claude Code.
