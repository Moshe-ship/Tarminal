# CLAUDE.md — Tarminal ترمنال

## What This Is
Native macOS terminal emulator with proper Arabic/RTL text support. First of its kind — every existing Mac terminal is broken for Arabic.

## Stack
- **Swift + SwiftUI**
- **SwiftTerm v1.13.0** — terminal emulation engine (VT100/xterm, PTY, buffer)
- **Core Text** — BiDi rendering using native UBA + Arabic shaping
- **Font cascade:** SF Mono (Latin) → Geeza Pro (Arabic)

## Build
```bash
cd /Users/mousaabumazin/Projects/Tarminal && swift build
```
Or open in Xcode and run. Builds as standalone .app bundle.

## What Works (Phase 1-3)
- Full terminal emulation (zsh shell)
- Arabic connected letters rendering
- **RTL BiDi overlay** — re-renders RTL lines with correct right-to-left direction
- iTerm2-style tabs (Cmd+T/W/1-9)
- **Tab drag reorder** — drag tabs to rearrange
- **Tab groups** — right-click to color-code tabs, group management
- BiDi line analyzer (detects RTL content)
- Cursor mapper (logical↔visual position)
- Settings panel (font, Arabic font, BiDi mode)
- **Cursor style** — block/underline/bar (wired to terminal)
- **Option as Meta key** (wired to terminal)
- **BiDi mode** — auto/ltr/rtl (wired to overlay)
- **File drag & drop** — drop files/images into terminal to paste path
- **Scrollback search (Cmd+F)** — uses SwiftTerm's built-in find bar
- Clickable URLs (hover to highlight)
- Window transparency/vibrancy
- Standalone .app bundle

## What's Left (Phase 4+)
- [ ] Split panes
- [ ] Full theme persistence (save custom themes)
- [ ] App icon
- [ ] macOS sandboxing for security
- [ ] BiDi escape sequences (freedesktop spec)
- [ ] GitHub repo + README
