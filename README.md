> **macuake-glass** is a fork of [menemy/macuake](https://github.com/menemy/macuake) with a translucent terminal
> and a macOS Terminal.app look out of the box. Upstream's work and license (MIT) are unchanged; see below.

## macuake-glass changes

- **Translucent terminal.** Upstream paints solid black behind the terminal in three places, so Ghostty's
  `background-opacity` never shows. This fork makes `GhosttyBackend`'s container layer, `GhosttyTerminalView`
  and the `PanelContentView` terminal area clear.
- **Bundled defaults** (`MaQuake/Defaults/`): `defaults.conf` is loaded *before* your own Ghostty config, so
  anything you set in `~/.config/ghostty/config` still wins. It sets a Terminal.app-like look: bundled Meslo (falls back to
  Menlo), 14pt, a `Mac Terminal` theme (`#171717` background, white text), block cursor, `background-opacity = 0.98`.
- **Bundled themes** (`Resources/ghostty/themes`): Mac Terminal, Terminal Basic, Pro, Pro Light, Homebrew, Novel,
  Man Page, Ocean, Grass, Red Sands, Apple System Colors (+ Light). All but `Mac Terminal` come from
  [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes) (MIT). Only `Mac Terminal` is applied by default. To use another bundled theme, give its full path in your own Ghostty config, e.g. `theme = /Applications/Macuake.app/Contents/Resources/ghostty/themes/Homebrew` (theme *names* only resolve if Ghostty.app is installed or the theme is in `~/.config/ghostty/themes`).
- **Bundled font:** Meslo LG M DZ for Powerline (Regular/Bold/Italic/Bold Italic, Apache-2.0, license included in
  `MaQuake/Defaults/Fonts`). It is registered per-process at launch through `ATSApplicationFontsPath`; nothing is
  installed into your system fonts.
- **No auto-update** from upstream (it would replace this build).
- `scripts/build-glass.sh`: reproducible build (ad-hoc signed by default, or `SIGN_ID="Developer ID Application: ..."`).
  `scripts/release-glass.sh`: Developer-ID sign, notarize, staple and publish a DMG.

Do **not** set `background-blur = macos-glass-*`: Macuake has no glass view, so the renderer then skips drawing the
background and the terminal turns fully transparent.

### Remote hosts and `clear`

If `clear` fails over SSH with `unknown terminal type`, add `shell-integration-features = cursor,path,title,ssh-env,ssh-terminfo` to your Ghostty config. Ghostty's `ssh` wrapper then installs its terminfo on the remote, or falls back to `xterm-256color`.

### Build and install (Apple Silicon, Xcode 26+)

```bash
git clone https://github.com/nsssayom/macuake-glass.git && cd macuake-glass
./scripts/build-glass.sh --install      # quits a running Macuake and replaces /Applications/Macuake.app
./scripts/clean-glass.sh                # afterwards: frees ~2 GB of build cache (everything is re-fetched on demand)
```

Or download the notarized DMG from [Releases](https://github.com/nsssayom/macuake-glass/releases) (when available).
A source build is ad-hoc signed, so macOS may ask you to approve it on first launch. Not affiliated with the upstream author.

---

# macuake

> **Alpha** — Quake-style drop-down terminal for macOS, powered by [Ghostty](https://ghostty.org).

One hotkey. Instant terminal. `Option+Space` slides it down from the top of any screen.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![License: MIT](https://img.shields.io/badge/License-MIT-blue)

## Features

- **GPU-accelerated** — GhosttyKit Metal renderer. True color, ligatures, GPU text shaping.
- **Hotkey toggle** — `Option+Space` (customizable) from any app. No Dock icon.
- **Tabs & split panes** — multiple sessions with horizontal/vertical splits.
- **Ghostty themes** — use any Ghostty config for fonts, colors, opacity, keybindings.
- **MCP server** — built-in HTTP server (port 19876) with 17 tools. Control from Claude Code, Cursor, or any MCP client.
- **Socket API** — Unix socket at `/tmp/macuake.sock` for scripting.
- **Auto-updates** — Sparkle integration with EdDSA-signed releases.
- **Multi-display** — follows cursor across screens, notch-aware.

## Install

Download from [Releases](https://github.com/menemy/macuake/releases), or:

```bash
curl -LO https://github.com/menemy/macuake/releases/latest/download/Macuake.dmg
open Macuake.dmg
# Drag to /Applications
```

### Build from source

Requires: macOS 14+, Swift 5.9+, [Zig 0.15.2](https://ziglang.org/download/) (for GhosttyKit).

```bash
git clone --recursive https://github.com/menemy/macuake.git
cd macuake
./scripts/build-ghostty.sh   # build GhosttyKit xcframework
swift build                   # debug build
```

## Usage

Launch macuake — it lives in the menu bar (no Dock icon). Press `Option+Space` to toggle.

| Shortcut | Action |
|----------|--------|
| `Option+Space` | Toggle terminal |
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Cmd+D` | Split horizontal |
| `Cmd+Shift+D` | Split vertical |
| `Cmd+]` / `Cmd+[` | Next / previous pane |
| `Cmd+1`..`9` | Switch to tab N |
| `Cmd+,` | Settings |

### Ghostty config

macuake uses your Ghostty config (`~/.config/ghostty/config`). Open it from Settings or:

```bash
echo '{"action":"state"}' | nc -U /tmp/macuake.sock
```

## MCP Server

Add to Claude Code:

```bash
claude mcp add --transport http macuake http://localhost:19876/mcp
```

17 tools available: `state`, `list`, `toggle`, `show`, `hide`, `pin`, `unpin`, `new_tab`, `focus`, `close_session`, `execute`, `read`, `paste`, `control_char`, `clear`, `split`, `set_appearance`.

### Pane support

```bash
# List tabs with pane tree
claude> list(include_panes=true)

# Focus a specific pane
claude> focus(pane_id="...")

# Navigate panes
claude> focus(direction="next")

# Close a pane (not the whole tab)
claude> close_session(pane_id="...")
```

## Socket API

See [API.md](API.md) for the full reference.

```bash
# Execute a command
echo '{"action":"execute","command":"ls -la"}' | nc -U /tmp/macuake.sock

# Read terminal output
echo '{"action":"read","lines":50}' | nc -U /tmp/macuake.sock

# Split pane
echo '{"action":"split","direction":"h"}' | nc -U /tmp/macuake.sock
```

## Architecture

```
MaQuake/Sources/MaQuake/
├── API/              # ControlServer (socket API)
├── MCP/              # MCPHTTPServer (MCP over HTTP)
├── Panes/            # PaneManager, PaneNode tree
├── Settings/         # SettingsView, HelpView
├── Tabs/             # TabManager, TabBarView
├── Terminal/         # GhosttyApp, GhosttyBackend, GhosttyTerminalView
├── Updates/          # SparkleUpdater
└── Window/           # WindowController, TerminalPanel, ScreenDetector
```

- **GhosttyKit** — vendored xcframework, GPU Metal terminal engine
- **KeyboardShortcuts** — global hotkey (sindresorhus)
- **Sparkle** — auto-updates
- **SPM** project (not Xcode), `swift build` / `swift test`

## License

MIT
