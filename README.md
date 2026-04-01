# Tarminal ترمنال

The first native macOS terminal emulator with proper Arabic and RTL text support.

Every terminal on Mac is broken for Arabic — iTerm2 has half-working experimental RTL, Ghostty renders disconnected letters, Alacritty has no RTL at all. Tarminal fixes this.

## Features

- **Arabic text rendering** — connected letters, ligatures, proper shaping via Core Text
- **BiDi support** — mixed Arabic + English on the same line
- **Full terminal emulation** — VT100/xterm compatible via SwiftTerm
- **Tabs** — Cmd+T new, Cmd+W close, Cmd+1-9 switch
- **Themes** — Dark, Light, Dracula, Nord, سراب (Sarab)
- **Native macOS** — Swift + SwiftUI, not Electron
- **Font cascade** — SF Mono for Latin, Geeza Pro for Arabic, automatic switching
- **Settings** — font size, Arabic font, BiDi mode, shell path, cursor style, opacity

## Install

### From Source

```bash
git clone https://github.com/mousaabumazin/Tarminal.git
cd Tarminal
swift build
cp .build/debug/Tarminal build/Tarminal.app/Contents/MacOS/Tarminal
open build/Tarminal.app
```

Requires: macOS 14+ (Sonoma), Xcode Command Line Tools

## Architecture

```
SwiftUI App Shell (tabs, settings, themes)
    ↓
BiDi Overlay View (re-renders RTL lines with Core Text)
    ↓
SwiftTerm Engine (VT100/xterm emulation, PTY, buffer)
    ↓
Core Text (Apple's native Arabic shaping + BiDi algorithm)
    ↓
PTY / zsh
```

The key insight: Core Text already implements the full Unicode Bidirectional Algorithm and Arabic shaping natively. No terminal on Mac uses it. Tarminal does.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+T | New tab |
| Cmd+W | Close tab |
| Cmd+1-9 | Switch to tab |
| Cmd+Shift+] | Next tab |
| Cmd+Shift+[ | Previous tab |
| Cmd+, | Settings |

## Themes

- **Tarminal Dark** — deep black with green cursor
- **Tarminal Light** — clean white
- **Dracula** — purple-accented dark
- **Nord** — arctic blue dark
- **سراب (Sarab)** — warm desert tones, designed for Arabic reading

## Tech Stack

- **Swift 5.9+** / **SwiftUI** / **macOS 14+**
- **SwiftTerm** v1.13.0 — terminal emulation engine
- **Core Text** — Arabic shaping, BiDi algorithm
- **AppKit** — native view rendering

## Why

440 million Arabic speakers. Zero proper terminal emulators.

## License

MIT

## Contributing

PRs welcome. The biggest area for contribution is Phase 2+ of the BiDi rendering engine — making Arabic lines flow right-to-left while keeping command output LTR.
