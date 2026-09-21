# DualCursor

<img src="https://raw.githubusercontent.com/sadecebar/DualCursor/main/assets/dualcursor.png" width="96" height="96" alt="DualCursor logo">

**Two physical mice. Two colored pointers. One Windows computer.**

DualCursor is a free, open-source Windows app that gives two physical mice their
own visible pointers. Move, click, and scroll with each mouse, and optionally
lock each pointer to a different monitor.

The main purpose is to use **two different mice on the same computer**.
Automation support makes this setup work with external tools such as
**TinyTask**; DualCursor itself is not a macro recorder or player.

**Automation is experimental, not fully independent input.** Simultaneous
TinyTask playback and manual browsing can still interfere with clicks,
selection, dragging, and focus. Two monitors and screen locks do not isolate
Windows input. This is not yet a reliable solution for unattended automation
alongside unrestricted manual use.

A typical setup is TinyTask using the orange pointer on monitor 2 while you
use the blue pointer to browse or work on monitor 1. The routing tries to keep
macro clicks at the automation pointer's saved position. Windows still shares
its foreground window and button state, so read the limitations before relying
on a macro. This reduces some interference; it does not create two isolated
computers or guarantee that every click reaches the intended application.

## Download and run

1. Open [Releases](https://github.com/sadecebar/DualCursor/releases/latest).
2. Download the **Windows x64 ZIP**, not the automatically generated Source code archive.
3. Extract the ZIP into a folder.
4. Connect two mice and double-click **DualCursor.exe**.

**Requirements:** Windows 10 or 11, x64. Two monitors are optional, but recommended
for automation alongside manual use. The packaged build requires no installer,
account, paid subscription, separate C++ runtime installation, or custom mouse
driver. Administrator privileges are not normally needed.

The download contains only:

```text
DualCursor/
    DualCursor.exe
    README.md
    LICENSE
```

The executable is unsigned. Windows may display a reputation warning. Only run
downloads you trust; do not disable Windows security to use it. A SHA-256
checksum is provided alongside the ZIP.

## First use

- **Mouse 1** has a blue pointer; **Mouse 2** has an orange pointer.
- The window shows the assigned devices and their connection status.
- Automatic assignment is used until you identify your mice explicitly.
- For ordinary two-mouse use without macros, choose **Automation: Off**.
- Minimize the window to keep using the pointers. Closing it stops DualCursor
  and restores normal Windows mouse control.

The **HID inputs** count can exceed the number of physical mice. A single mouse
or receiver can expose several interfaces. Names come from Windows and may be
generic, such as "HID-compliant mouse", or localized.

### Assign the correct physical mice

If colors are assigned to the wrong devices, or both devices control the same
pointer, right-click the DualCursor notification-area icon and choose
**Re-identify devices...**. Follow the console prompts, moving only the requested
mouse. The app stops during identification; launch it again afterward.

Alternatively, close the app and run this from its folder:

```bat
DualCursor.exe --identify
```

Assignments are saved for your Windows user. Re-identify after changing USB
ports or receivers if devices no longer match their saved assignments.

## Lock a pointer to a monitor

Click **Screen 1**, **Screen 2**, or another detected screen beside a mouse.
The selected button is highlighted and the pointer stays inside that monitor.
Click the same button again to unlock it, or another button to switch.

Each mouse has its own lock. A pointer outside its newly selected screen moves
to the nearest edge. Unplugging the monitor releases its lock. Monitor locks
last for the current session and reset when DualCursor closes.

## Use TinyTask or another automation tool

1. Assign the physical mice and confirm their colors.
2. Lock **Mouse 1** to your working monitor, for example **Screen 1**.
3. Lock **Mouse 2** to the macro's monitor, for example **Screen 2**.
4. Select **Automation: Mouse 2**. This is the default on startup.
5. Test a short TinyTask playback with coordinates inside the automation monitor.
6. Use Mouse 1 on your working monitor while the orange pointer shows the macro.

TinyTask is separate and is not included. DualCursor does not start, stop,
pause, record, or edit its macros. Keep the target application's position and
display layout consistent with the recording. The Automation selection resets
when DualCursor closes.

### What automation routing does

- Mirrors external movement on the selected colored pointer, including direct
  changes to the Windows cursor position.
- Intercepts supported injected mouse buttons and scroll events, then sends
  them once at the automation pointer's saved position.
- Ignores DualCursor's own tagged events to prevent duplicate clicks and loops.
- Keeps manual and automation button presses/releases from being mixed.
- Drops new automation presses and scroll events outside its locked monitor.
- Releases held automation buttons when switching the selected mouse, turning
  automation off, or closing normally.

**A held button takes priority.** While one input source holds a mouse button,
conflicting clicks from the other are skipped, including their matching releases.
Skipped clicks are not replayed later, and TinyTask is not paused.

**Off** restores normal pass-through behavior for external automation. Routing
applies to supported injected mouse input from *all* programs, not just TinyTask.
The mouse hook has no reliable originating-program identity. Keyboard macros
and programs that send messages directly to a target window are not routed.

## Important limitations

Windows still has one shared system cursor, button state, and foreground window.
DualCursor draws the separate pointers and coordinates their input.

- Clicking between applications can change focus and affect typing or macro timing.
- Moving a physical mouse restores its hover position after a macro click when
  no source holds a button. This does not give both applications independent
  hover or focus, and switching foreground windows can delay input.
- Two simultaneous independent drags are not supported. Direct external cursor
  warps can still disturb a drag even when conflicting clicks are filtered.
- Direct cursor warps have no reliable source identity. A warp that leaves the
  system cursor at the same position cannot be distinguished from no movement.
  Relative macro movement also uses the shared system cursor as its starting
  position, which manual input can change.
- Relative-motion games, cursor-capturing applications, exclusive fullscreen,
  elevated windows, and protected games may behave differently or reject input.
  Compatibility with every game, including Roblox, is not guaranteed.
- Direct cursor-position polling runs approximately every 16 ms; very brief
  movement between samples may not appear on the colored pointer.
- Automation mirroring/routing is disabled if the Windows cursor cannot be
  hidden or the app falls back to its one-pixel cursor safety cage.

Use automation only where the target application's rules permit it.

## Stop and recover

- Click **Close DualCursor**, close the window, or choose **Stop DualCursor**
  from its notification-area menu.
- Emergency shortcut: **Ctrl+Alt+Shift+Q**.
- **Ctrl+Alt+Del** is not intercepted by DualCursor.

A watchdog releases input capture if the main loop stalls. A separate cleanup
process attempts to restore the normal pointer after an unexpected exit.
If the Windows cursor remains hidden, run:

```bat
DualCursor.exe --restore-cursor
```

For a time-limited trial:

```bat
DualCursor.exe --seconds=60
```

## Settings, logs, and privacy

The app runs locally, with no built-in telemetry, online account, or updater.
Settings and diagnostic logs are stored under:

```text
%APPDATA%\DualCursor\dualcursor.ini
%APPDATA%\DualCursor\dualcursor.log
```

The settings file is written when device assignments are saved. To customize
colors and sensitivity, close the app and edit the relevant sections:

```ini
[seat0]
color=4A90D9
sensitivity=1.00

[seat1]
color=E86A33
sensitivity=1.00
```

Restart after editing. `seat0` corresponds to Mouse 1 and `seat1` to Mouse 2.
Do not distribute your settings file as a default: it can contain machine-specific
device paths. Logs can contain device identifiers and window information;
review them before posting them publicly.

To uninstall, close DualCursor and delete the extracted folder. Optionally
delete `%APPDATA%\DualCursor` to remove settings and logs.

## Troubleshooting

| Symptom | What to check |
| --- | --- |
| Wrong mouse/color assignment | Close the app, run `--identify`, and restart. |
| Macro moves but its pointer is invisible | Select the correct Automation mouse; check the log for fallback mode. |
| Macro clicks are skipped | Check screen bounds and whether another button is held. |
| A game stops responding while you work elsewhere | It may require foreground focus; separate pointers cannot remove that requirement. |
| Cursor stays hidden after a crash | Run `--restore-cursor`. |

Additional commands: `--list` lists devices; `--probe` and `--probe-echo` check
input compatibility; `--watch` helps identify interfaces; `--help` lists diagnostics.
Use `--verbose` only while investigating a problem.

Report reproducible problems in [Issues](https://github.com/sadecebar/DualCursor/issues).
Include your Windows version, monitor layout, affected application, and steps
to reproduce. Remove personal device identifiers from attached logs.

## Source and development

Source: [sadecebar/DualCursor](https://github.com/sadecebar/DualCursor).

DualCursor uses C++17, native Win32 controls, Raw Input, a low-level mouse hook,
tagged `SendInput` events, and transparent pointer windows. Automation clicks
are queued from the hook to the main thread, which applies screen bounds and
button ownership before dispatching them.

To build, install Visual Studio 2022 Build Tools with **Desktop development
with C++** and a Windows SDK, then run `build.cmd`. This compiles the source
and embeds the icon in `DualCursor.exe`.

The public repository is intentionally small: `src/` contains the program,
`assets/` contains its logo and icon resource, and `build.cmd` builds it.
These source files are for inspecting or rebuilding the app; they are not
needed by someone using the Windows download. Development tests, internal
guides, and optional helper scripts are kept out of the public file list.

## License and credits

Free and open source under the **MIT License**. See `LICENSE` for the full
terms and warranty disclaimer.

Based on [openMouse](https://github.com/alstonmendonca/openMouse) by **Alston
Mendonca**. The upstream copyright notice is preserved in `LICENSE`.
This README describes current DualCursor behavior.

DualCursor is not affiliated with TinyTask, Microsoft, or Roblox.
