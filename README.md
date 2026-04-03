# Tarminal ترمنال

Native macOS terminal with Arabic support, Metal GPU rendering, and Touch ID integration.

## Features

- **Connected Arabic letters** — proper shaping via Core Text (every other terminal breaks Arabic)
- **Metal GPU rendering** — hardware-accelerated on Apple Silicon
- **Touch ID for SSH** — Secure Enclave keys via SSH_SK_PROVIDER (automatic)
- **Touch ID for sudo** — one-click setup in Settings
- **Tab groups** — color-coded, drag to reorder, Cmd+1-9 to switch
- **Session restore** — tabs, directories, colors persist on relaunch
- **Drag & drop** — drop files into terminal to paste escaped paths
- **Find in scrollback** — Cmd+F, Cmd+G, Cmd+Shift+G
- **5 themes** — Dark, Light, Dracula, Nord, Sarab (سراب)
- **Notifications** — macOS alerts when commands finish or bell fires in background
- **Tab activity** — blue dot on background tabs with new output
- **Full terminal** — zsh, bash, fish. VT100/xterm via SwiftTerm. Clickable URLs.
- **All settings wired** — cursor style/blink, scrollback, bell, Option-as-Meta, opacity

## Install

### Download

Grab the DMG from [Releases](https://github.com/Moshe-ship/Tarminal/releases).

### From Source

```bash
git clone https://github.com/Moshe-ship/Tarminal.git
cd Tarminal
swift build -c release
cp .build/release/Tarminal build/Tarminal.app/Contents/MacOS/Tarminal
open build/Tarminal.app
```

Requires macOS 14+ (Sonoma), Xcode Command Line Tools.

## Touch ID Setup

**SSH** — automatic. Tarminal sets `SSH_SK_PROVIDER` on every shell launch. Generate a Secure Enclave key:

```bash
ssh-keygen -t ecdsa-sk
```

Then add the public key to your server. Next SSH connection prompts Touch ID.

**Sudo** — go to Settings > System > Touch ID > click Enable. One-time setup.

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| Cmd+T | New tab |
| Cmd+W | Close tab |
| Cmd+1-9 | Switch to tab |
| Cmd+Shift+] / [ | Next / previous tab |
| Cmd+F | Find in scrollback |
| Cmd+G | Find next |
| Cmd+Shift+G | Find previous |
| Cmd+, | Settings |

## Architecture

```
SwiftUI App (tabs, settings, themes, session restore)
    ↓
TarminalTerminalView (bell, Metal, notifications)
    ↓
SwiftTerm Engine (VT100/xterm, PTY, buffer)
    ↓
Core Text (Arabic shaping) + Metal (GPU rendering)
    ↓
PTY / zsh
```

## Tech Stack

- Swift 5.9+ / SwiftUI / macOS 14+
- SwiftTerm v1.13.0 — terminal emulation
- Metal — GPU rendering
- Core Text — Arabic letter shaping
- Secure Enclave — SSH key storage
- UserNotifications — macOS alerts

## License

MIT
