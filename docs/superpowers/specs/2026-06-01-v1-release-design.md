# ClaudeBar v1.0 Release — Design Spec

**Date:** 2026-06-01
**Scope:** GitHub repo setup, release packaging, CI/CD, README updates

---

## Goal

Ship ClaudeBar as a public GitHub release. Anyone who uses Claude Code can download a pre-built `.app`, bypass Gatekeeper once, and have a working menubar token monitor. Homebrew cask is out of scope for v1.0 but the release URL structure will be stable enough to add later.

---

## Section 1: Repository Structure

Repo name: `claudebar` at `github.com/<owner>/claudebar`.

```
claudebar/
├── Sources/main.swift         # Full Swift app
├── build.sh                   # Compile + bundle + sign → ClaudeBar.app
├── make_icon.swift            # Generate AppIcon.icns from AppNameIcon.webp
├── AppNameIcon.webp           # Source icon (orange bg, dark "C%")
├── AppIcon.icns               # Generated — committed so CI doesn't need to regenerate
├── claudebar.lua              # Legacy Hammerspoon version (kept for reference)
├── init.lua                   # Legacy Hammerspoon init
├── release.sh                 # Version bump + tag + push script
├── .gitignore
├── README.md
├── CLAUDE.md
├── CHANGELOG.md
└── .github/
    └── workflows/
        └── release.yml        # CI: build + zip + GitHub release on v* tag
```

`.gitignore` excludes: `ClaudeBar.app/`, `claudebar.app/`, `claudebar_bin`, `AppIcon.iconset/`, `.DS_Store`.

---

## Section 2: Versioning & Release Script

`release.sh <version>` — run locally after editing `CHANGELOG.md` with release notes.

**Behaviour:**
1. Abort if working tree is dirty (uncommitted changes)
2. Update `CFBundleVersion` and `CFBundleShortVersionString` in `build.sh` to `<version>`
3. Verify `CHANGELOG.md` has a `## [<version>]` section — abort if missing
4. Commit: `chore: release v<version>`
5. Tag: `v<version>`
6. Push commit + tag to origin → triggers CI

**Workflow:**
```bash
# 1. Edit CHANGELOG.md — add ## [1.0.0] section with release notes
# 2. Run:
./release.sh 1.0.0
```

---

## Section 3: GitHub Actions — release.yml

**Trigger:** `push` to tags matching `v*`

**Runner:** `macos-latest` (required for AppKit/Swift)

**Steps:**
1. Checkout repo
2. Run `swift make_icon.swift` to regenerate icon (ensures CI-built app has correct icon)
3. Run `bash build.sh` to compile and bundle `ClaudeBar.app`
4. Strip xattrs and re-sign ad-hoc: `xattr -cr ClaudeBar.app && codesign --force --deep --sign - ClaudeBar.app`
5. Zip: `zip -r ClaudeBar-${{ github.ref_name }}.zip ClaudeBar.app`
6. Extract release notes from the matching `## [X.Y.Z]` section in `CHANGELOG.md`
7. Create GitHub release via `softprops/action-gh-release` with:
   - Name: `ClaudeBar ${{ github.ref_name }}`
   - Body: extracted CHANGELOG section
   - Asset: `ClaudeBar-${{ github.ref_name }}.zip`

---

## Section 4: README Updates

Add **Install** section before the existing build-from-source content:

```markdown
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

### Build from source
...
```

---

## Out of Scope (v1.0)

- Notarization / Apple Developer signing
- Homebrew cask (add after v1.0 once release URL pattern is confirmed stable)
- Notifications or threshold alerts
- Preferences UI
- Auto-update mechanism
