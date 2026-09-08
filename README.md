# OmaNews (omarchy-omacom-news)

Official Omarchy Linux news dispatches, distribution releases, and desktop notification hub for Omarchy.

## Features
- **Multi-Feed Aggregator**: Combines official Omarchy News (`omarchy.org/news/rss.xml`), GitHub distribution releases (`omacom/omarchy/releases.atom`), and local OS package version checks (`pacman -Q omarchy`).
- **Category Classification**: Automatic categorization for `Release`, `Foundation`, `Distro`, `Community`, and `Ecosystem` dispatches with color-coded badges.
- **100% Native Rust Engine**: Hardened backend adhering strictly to Omarchy Security Architecture Standards (`AGENTS.md`):
  - Isolated process groups (`cmd.process_group(0)`) and non-blocking POSIX polling with monotonic deadlines.
  - Strict bounded buffers preventing memory overruns.
  - POSIX `0600` atomic file writes and `0700` state directories with symlink rejection.
- **Desktop Notifications**: Native desktop notifications (`notify-send`) when fresh releases or news dispatches land.
- **Native Quickshell UI**: Tabbed filter bar (`Tümü`, `Haberler`, `Sürümler`, `Vakıf`), live system version badge, and seamless article opener.
- **Offline Resilience**: Automatic caching and robust fallback dispatches.

## Build & Install
```bash
cargo build --release --locked
```
Or build the native Arch Linux package:
```bash
makepkg -si
```
