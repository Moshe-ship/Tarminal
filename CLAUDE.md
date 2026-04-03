# CLAUDE.md — Tarminal ترمنال

## What This Is
Native macOS terminal with Metal GPU rendering, Touch ID, and connected Arabic letters.

## Stack
- **Swift + SwiftUI**
- **SwiftTerm v1.13.0** — terminal emulation (VT100/xterm, PTY, buffer)
- **Metal** — GPU-accelerated rendering
- **Core Text** — Arabic letter shaping (connected forms)
- **Secure Enclave** — SSH key storage via SSH_SK_PROVIDER
- **UserNotifications** — macOS notification center alerts

## Build
```bash
swift build -c release
cp .build/release/Tarminal build/Tarminal.app/Contents/MacOS/Tarminal
open build/Tarminal.app
```

## What Works
- Full terminal emulation (zsh, bash, fish)
- Metal GPU rendering (toggleable in Settings)
- Connected Arabic letters (Core Text, automatic)
- Touch ID for SSH (Secure Enclave keys, automatic)
- Touch ID for sudo (one-click setup in Settings)
- Tab groups with color coding (right-click)
- Tab drag reorder
- Tabs persist on switch (ZStack, no process kill)
- Session restore on relaunch
- macOS notifications (process finished, bell in background)
- Tab activity indicator (blue dot on background tabs)
- Cmd+F scrollback search
- File drag & drop (pastes escaped path)
- 5 themes (Dark, Light, Dracula, Nord, Sarab)
- All settings wired: cursor style/blink, scrollback, bell, dock bounce, Option-as-Meta, opacity, title bar style, Metal toggle
- Clickable URLs
- Close tab confirmation

## Architecture
```
TarminalApp (SwiftUI, session restore, notifications)
  └ ContentView (ZStack of all tabs)
      └ TerminalContainerView (NSViewRepresentable)
          └ TarminalTerminalView (bell, Metal)
              └ SwiftTerm (VT100/xterm, PTY)
                  └ Core Text (Arabic shaping)
                  └ Metal (GPU rendering)
```
