# skills-sync

Sync Claude Code **skills** and **plugins** across devices via GitHub.

## Features

- **Push/Pull skills** to/from a GitHub repo
- **Push/Pull plugins** — backup and restore installed plugins & marketplace list across devices
- **Diff** local vs remote to see what's changed
- **Conflict detection** with interactive resolution
- **Self-update** — update the plugin with one command
- **Zero dependencies** beyond `gh` CLI (no build step, no runtime)

## Prerequisites

- [GitHub CLI (`gh`)](https://cli.github.com/) installed and authenticated
- A GitHub account

## Installation

### From the Plugin Marketplace

```
/plugin marketplace add JFan5/skills-sync
/plugin install skills-sync@skills-sync
```

### Manual / Development

```bash
claude --plugin-dir ./skills-sync
```

### Update

```
/skills-sync:update
```

Then run `/plugin install skills-sync@skills-sync` and restart Claude Code.

## Quick Start

### Sync Skills

```
/skills-sync:setup           # Configure GitHub repo (creates if needed)
/skills-sync:push --all      # Upload all local skills
```

On another machine:

```
/skills-sync:setup           # Same repo name
/skills-sync:pull --all      # Download all skills
```

### Sync Plugins

```
/skills-sync:push-plugins    # Backup installed plugins & marketplaces
```

On another machine:

```
/skills-sync:pull-plugins    # Get marketplace add & plugin install commands
```

## Commands

### Skills

| Command | Description |
|---------|-------------|
| `/skills-sync:setup [repo-name]` | Configure GitHub repo for syncing (default: `claude-skills`) |
| `/skills-sync:list [all\|skills\|plugins\|local\|remote]` | List skills and plugins with sync status |
| `/skills-sync:status` | Show config, auth, and sync status |
| `/skills-sync:diff [skill-name]` | Unified diff of local vs remote |
| `/skills-sync:push [skill-name\|--all]` | Push skills to GitHub |
| `/skills-sync:pull [skill-name\|--all] [--force]` | Pull skills from GitHub |

### Plugins

| Command | Description |
|---------|-------------|
| `/skills-sync:push-plugins` | Backup installed plugins & marketplace list to GitHub |
| `/skills-sync:pull-plugins` | Restore plugins list and show install commands |

### Utility

| Command | Description |
|---------|-------------|
| `/skills-sync:update` | Update skills-sync plugin to latest version |

## How It Works

The plugin uses `gh` CLI to interact with the GitHub Contents API. Skills are stored as directories in a configurable GitHub repository. Plugin configurations (`installed_plugins.json` and `known_marketplaces.json`) are backed up to the same repo under `plugins-config/`.

Each command is a markdown file that instructs Claude to run the corresponding shell script.

### Configuration

Stored in `~/.claude/skills-sync.json`:

```json
{
  "repo": "username/claude-skills",
  "branch": "main",
  "skills_dir": "skills"
}
```

### Sync State

Tracked in `~/.claude/skills-sync-state.json` to detect conflicts and show last sync times.

## License

MIT
