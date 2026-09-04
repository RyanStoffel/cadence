# Cadence

A native macOS Pomodoro timer and local work log.

## What it does

- Runs 25-minute focus, 5-minute short break, and 15-minute long break timers
- Requires a clear work label before a focus session starts
- Preserves a running or paused timer across window closes and app restarts
- Logs completed focus blocks with labels, optional details, and exact active time
- Adds missed work manually in five-minute increments
- Shows today and weekly totals against a general weekly goal
- Uses Monday through Sunday reporting weeks and rounds the total to the nearest 0.25 hour
- Copies a one-line weekly log entry to the clipboard
- Exports the complete work log as CSV
- Keeps data local in `~/Library/Application Support/Cadence/state.json` with an automatic backup
- Provides a compact menu-bar controller — set the work label, adjust the timer duration, and
  start/pause/finish focus blocks without opening the main window

## Build

Requires macOS 14 or newer and Xcode command-line tools.

```bash
swift test
./Scripts/package_app.sh
```

The signed app bundle is created at `build/Cadence.app`.

## Install

```bash
brew install ryanstoffel/taps/cadence
```

Cadence is not notarized. On first launch, go to
**System Settings > Privacy & Security**, find the message about Cadence, and click
**Open Anyway**.

### Build from source

```bash
cp -R "build/Cadence.app" ~/Applications/
open "$HOME/Applications/Cadence.app"
```
