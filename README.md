# MacFolderActions

Shell scripts that automate macOS folder housekeeping.

---

## Screenshots.sh

macOS saves screenshots to the Desktop by default. Over time this clutters the Desktop with dozens of `Screenshot …` files. This script watches the Desktop and automatically moves any screenshot into an organised folder:

```
~/Pictures/Screenshots/<Year>-<Month>/
```

Example: a screenshot taken in May 2026 goes to `~/Pictures/Screenshots/2026-May/`.

### Quick Install

```zsh
git clone https://github.com/AgnellusX1/MacFolderActions.git
cd MacFolderActions
./install.sh
```

That's it. The agent starts immediately and runs automatically at every login.

To uninstall:

```zsh
./uninstall.sh
```

### What it does

- **On startup:** scans `~/Desktop` and moves any existing screenshots immediately
- **While running:** uses [fswatch](https://github.com/emcrisostomo/fswatch) to listen for FSEvents (kernel-level, zero idle CPU) and moves new screenshots the moment they appear
- Creates the destination folder if it does not exist — re-evaluated on every move, so month rollovers are handled correctly
- If a file with the same name already exists at the destination, appends a counter suffix (`Screenshot … _1.png`, `_2.png`, …) instead of overwriting
- Shows a macOS notification on success or failure
- Uses Finder as a fallback for all file operations — avoids macOS TCC (Privacy) blocks that affect launchd agents running directly as `/bin/zsh`

### Requirements

- macOS (uses `osascript` and Finder for file operations and notifications)
- zsh (default shell on macOS Catalina and later)
- Homebrew — `install.sh` installs it automatically if missing (supports both Intel and Apple Silicon)

### First-run permission prompt

The first time the agent moves a screenshot, macOS may show:

> *"zsh would like to control Finder"*

Click **OK**. This is a one-time Automation permission that allows the agent to instruct Finder to move files. It will not appear again.

**Why Finder?** macOS TCC (Transparency, Consent, and Control) blocks direct `mv` operations on `~/Desktop` and `~/Pictures` for launchd background agents. Granting Full Disk Access to `/bin/zsh` does not solve this because macOS ignores per-binary TCC grants for SIP-protected system binaries. Having Finder perform the actual move sidesteps this entirely — Finder has its own full filesystem access.

### How install.sh works

1. Installs Homebrew if not present (and correctly adds it to `PATH` on Apple Silicon)
2. Installs `fswatch` via Homebrew
3. Makes `Screenshots.sh` executable
4. Writes a `launchd` plist to `~/Library/LaunchAgents/` with the correct `HOME` and `PATH` environment variables set — required because launchd runs with a minimal environment
5. Loads the agent immediately via `launchctl bootstrap`

The agent starts at login automatically from then on. Re-running `install.sh` is safe — it unloads the existing agent before reloading.

### Manual usage

To run without installing as a login agent:

```zsh
chmod +x Screenshots.sh
./Screenshots.sh
```

Press `Ctrl+C` to stop.

### Logs

| File | Contents |
|---|---|
| `/tmp/screenshot-mover.log` | Normal output (startup scan, watching status) |
| `/tmp/screenshot-mover.err` | Errors (permission failures, move failures) |

### Troubleshooting

**Screenshots not moving**

Check the agent is running:
```zsh
launchctl print gui/$(id -u)/com.local.screenshot-mover
```
Look for `state = running` and `last exit code = (never exited)`. If it shows `last exit code = 1`, check `/tmp/screenshot-mover.err`.

**"fswatch not found" in the error log**

The launchd agent is not finding `fswatch` because `PATH` is not set correctly in the plist. Re-run `./install.sh` — it now resolves the full path to `fswatch` at install time and writes it into the plist automatically.

**"Could not move" notification / `Operation not permitted` in error log**

macOS TCC is blocking direct file access. The script uses Finder as a fallback automatically, but Finder needs Automation permission first. Go to **System Settings → Privacy & Security → Automation** and make sure `zsh` has permission to control Finder. If the entry is missing, take a screenshot — macOS will show a one-time prompt to grant it.

**Agent keeps restarting**

Run `./uninstall.sh` then `./install.sh` to get a clean install.

### Configuration

| What | Where |
|---|---|
| Destination folder pattern | Edit `_screenshots_folder()` in `Screenshots.sh` |
| Watched folder | Change `"$HOME/Desktop"` in the `fswatch` call |
