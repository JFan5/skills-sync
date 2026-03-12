---
name: pull-plugins
description: Pull plugins list from GitHub and show install commands
---

Restore your Claude Code plugins on a new device by fetching the saved plugin configuration from GitHub.

Run the pull-plugins script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/pull-plugins.sh"
```

The script outputs the `/plugin marketplace add` and `/plugin install` commands needed to restore all plugins. Present these clearly to the user so they can run them in Claude Code.

If the user wants, offer to run the marketplace add commands via bash (`gh` equivalent) where possible, but note that `/plugin install` must be run within Claude Code.
