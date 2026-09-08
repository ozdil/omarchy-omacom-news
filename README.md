# OmaNews - Official Omarchy Linux News and Release Hub

Official Omarchy Linux news dispatches, distribution releases, and desktop notification hub for Omarchy Linux.

Author: Ozan Ozdil (ozdil)  
License: MIT  
Plugin ID: ozdil.omacom-news

---

## Features

- Multi-Feed Aggregator: Combines official Omarchy News (`omarchy.org/news/rss.xml`), GitHub distribution releases (`omacom/omarchy/releases.atom`), and local OS package version checks (`pacman -Q omarchy`).
- Category Classification: Automatic categorization for Release, Foundation, Distro, Community, and Ecosystem dispatches with clean status badges.
- Native Rust Engine: Hardened backend adhering strictly to Omarchy Security Architecture Standards (AGENTS.md).
- Desktop Notifications: Native desktop alerts (`notify-send`) when fresh releases or news dispatches are published.
- Native Quickshell UI: Filter tabs (All, News, Releases, Foundation), live system version badge, and seamless article opener.
- Offline Resilience: Automatic caching and robust fallback dispatches for offline operation.

---

## Requirements

- cargo and rustc (Rust toolchain, for building from source)
- libnotify (for desktop alerts via notify-send)
- pacman (for local package version checks)

---

## Installation and Setup

### Why Building from Source is Required
Under the Omarchy Linux Security Standards (AGENTS.md Rule 5.3), precompiled binaries are strictly forbidden from Git repositories to guarantee user system integrity. Therefore, the native engine must be compiled from source on your local machine after adding the plugin.

### Step 1: Add the Plugin to Omarchy
```bash
omarchy plugin add https://github.com/ozdil/omarchy-omacom-news.git
```

### Step 2: Build the Native Engine
Navigate to the plugin directory and compile the engine:
```bash
cd ~/.config/omarchy/plugins/ozdil.omacom-news
cargo build --release --locked
install -m 755 target/release/omacomnews-engine ./omacomnews-engine
```

### Step 3: Add to Omarchy Shell Configuration
Add `ozdil.omacom-news` to `bar.layout.right` in `~/.config/omarchy/shell.json`:
```json
{
  "id": "ozdil.omacom-news"
}
```

### Step 4: Restart Shell
```bash
omarchy-restart-shell
```

---

## CLI Usage

OmaNews provides standalone CLI commands:

```bash
# Output formatted status summary
omacomnews-engine --status

# Output machine-readable JSON for integration
omacomnews-engine --json

# Force refresh feed data
omacomnews-engine --refresh
```

---

## Security and Architecture Standards

OmaNews complies strictly with the Omarchy Linux Security Standards (AGENTS.md):
- Subprocess Isolation: Process executions run in isolated process groups (`cmd.process_group(0)`) with non-blocking I/O and strict monotonic deadlines.
- Memory Limits: Bounded buffers prevent memory overruns during feed parsing.
- State File Hardening: Atomic file operations are written with POSIX mode 0600 permissions. State directories use mode 0700. Symlinks are rejected.
- Plain Text UI: All dynamic text rendered in QML components utilizes `textFormat: Text.PlainText` to prevent script and markup injection.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
