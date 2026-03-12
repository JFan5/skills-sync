---
name: sync-guidance
description: Contextual guidance for syncing Claude Code skills across devices
triggers:
  - sync skills
  - backup skills
  - transfer skills
  - share skills
  - skills across devices
  - skills on another machine
---

# Skills Sync Guidance

When the user asks about syncing, backing up, transferring, or sharing Claude Code skills across devices, guide them through the skills-sync plugin commands:

## Quick Start
1. **Setup**: Run `/skills-sync:setup` to configure a GitHub repo for storing skills
2. **Push**: Run `/skills-sync:push --all` to upload all local skills to GitHub
3. **Pull** (on another device): Run `/skills-sync:setup` then `/skills-sync:pull --all`

## Available Commands
- `/skills-sync:setup [repo-name]` - Configure the GitHub repository
- `/skills-sync:list [local|remote|all]` - See what skills exist where
- `/skills-sync:status` - Check configuration and sync status
- `/skills-sync:diff [skill-name]` - Compare local vs remote versions
- `/skills-sync:push [skill-name|--all]` - Upload skills to GitHub
- `/skills-sync:pull [skill-name|--all] [--force]` - Download skills from GitHub

## Prerequisites
- `gh` CLI installed and authenticated (`gh auth login`)
- A GitHub account

## How It Works
Skills are stored in a GitHub repository using the GitHub Contents API via the `gh` CLI. Each skill is a directory containing a `SKILL.md` file and optional supporting files. The plugin tracks sync state locally to detect conflicts and show sync status.
