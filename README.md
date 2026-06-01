# ClaudeBar

macOS menubar app that shows your Claude Code token usage at a glance.

## What it does

Displays two lines in the macOS menubar:
- **Top:** session usage % and time until session reset
- **Bottom:** weekly usage % and time until weekly reset

Reads your token from the macOS Keychain (same place Claude Code stores it) and polls the Anthropic usage API every 60 seconds.

## Install

### Download (recommended)

1. Download `ClaudeBar-vX.Y.Z.zip` from [Releases](../../releases/latest)
2. Unzip and drag `ClaudeBar.app` to `/Applications/`
3. First launch — Gatekeeper will block it (ad-hoc signed, not notarized):
   ```bash
   xattr -cr /Applications/ClaudeBar.app
   open /Applications/ClaudeBar.app
   ```
   Or: right-click → Open → Open anyway.

Use the menubar icon menu to enable **Launch at Login**.

### Build from source

#### Prerequisites

- macOS 13+
- Xcode command line tools: `xcode-select --install`
- Claude Code installed and authenticated (token stored in Keychain)

#### Build

```bash
# Regenerate icon (only needed when AppNameIcon.webp changes)
swift make_icon.swift

# Build ClaudeBar.app
bash build.sh

# Install
cp -r ClaudeBar.app /Applications/
xattr -cr /Applications/ClaudeBar.app
open /Applications/ClaudeBar.app
```

## Releasing a new version

```bash
# 1. Add release notes under a new ## [X.Y.Z] section in CHANGELOG.md
# 2. Run:
./release.sh X.Y.Z
```

This bumps the version in `build.sh`, commits, tags, and pushes. GitHub Actions builds and publishes the release automatically.
