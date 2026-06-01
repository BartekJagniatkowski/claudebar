# ClaudeBar

macOS menubar app that shows your Claude Code token usage at a glance.

## What it does

Displays two lines in the macOS menubar:
- **Top:** session usage % and time until session reset
- **Bottom:** weekly usage % and time until weekly reset

Reads your token from the macOS Keychain (same place Claude Code stores it) and polls the Anthropic usage API every 60 seconds.

## Getting started

### Prerequisites

- macOS 13+
- Xcode command line tools: `xcode-select --install`
- Claude Code installed and authenticated (token stored in Keychain)

### Build

```bash
# Regenerate icon (only needed when AppNameIcon.webp changes)
swift make_icon.swift

# Build ClaudeBar.app
bash build.sh
```

### Install

```bash
cp -r ClaudeBar.app /Applications/
open /Applications/ClaudeBar.app
```

Use the menubar icon menu to enable **Launch at Login**.
