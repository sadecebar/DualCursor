# Developing DualCursor

The source repository and the downloadable app are intentionally separate.
Users need the executable, not the compiler, tests, or project files.

## Requirements

- Windows 10/11, x64.
- Visual Studio 2022 or Build Tools with **Desktop development with C++**,
  MSVC v143, and a Windows SDK.
- Windows PowerShell for the packaging and GUI test scripts.

## Build

From the repository root:

```bat
build.cmd
```

This finds MSVC through `vswhere`, compiles C++17, and produces `DualCursor.exe`.
The release build uses the static C++ runtime (`/MT`). Build tools are not
needed on an end user's computer.

To avoid overwriting a running executable:

```bat
build.cmd build\DualCursor-next.exe
```

Alternatively, open `DualCursor.sln`, select **x64**, and build **Debug** or
**Release**. Output goes to `bin\Debug` or `bin\Release`.

CMake is also supported:

```bat
cmake -S . -B build\cmake -A x64
cmake --build build\cmake --config Release
```

## Source layout

| Path | Responsibility |
| --- | --- |
| `src/main.cpp` | GUI, raw input, event routing, focus, tray, and safety handling |
| `src/overlay.cpp` | Transparent, color-tinted cursor windows |
| `src/devices.cpp` | Device enumeration and Windows device names |
| `src/config.cpp` | INI settings, legacy settings migration, and logging |
| `src/openmouse.h` | Shared types and declarations |
| `src/screen_lock.h` | Per-mouse monitor bounds |
| `src/automation_cursor.h` | Distinguishing external motion from app-generated motion |
| `src/automation_input.h` | Thread-safe automation queue and button-pair filtering |
| `tests/` | Unit tests and interactive Windows regression tests |
| `tools/` | Optional identification, compatibility, and recovery launchers |
| `docs/UPSTREAM_README.md` | Historical upstream documentation, not the current user guide |

## Test safely

Close other instances of DualCursor before testing. GUI tests move the system
pointer and may inject clicks into test windows. Leave physical mice still and
stop other macros while they run. Do not run multiple GUI tests simultaneously.

Use `--seconds=60` when manually testing input changes. The emergency shortcut is
`Ctrl+Alt+Shift+Q`. Keep the watchdog and shutdown restoration paths intact.

In an **x64 Native Tools Command Prompt**, compile and run the unit tests:

```bat
cl /nologo /std:c++17 /EHsc /W4 /DNOMINMAX /Fo:build\screen_lock_test.obj /Fe:build\screen_lock_test.exe tests\screen_lock_test.cpp
build\screen_lock_test.exe
cl /nologo /std:c++17 /EHsc /W4 /DNOMINMAX /Fo:build\automation_cursor_test.obj /Fe:build\automation_cursor_test.exe tests\automation_cursor_test.cpp
build\automation_cursor_test.exe
cl /nologo /std:c++17 /EHsc /W4 /DNOMINMAX /Fo:build\automation_input_test.obj /Fe:build\automation_input_test.exe tests\automation_input_test.cpp
build\automation_input_test.exe
```

After `build.cmd build\DualCursor-next.exe`, run the GUI tests in PowerShell:

```powershell
.\tests\gui_automation.ps1
.\tests\gui_screen_lock.ps1
.\tests\gui_minimize.ps1 -CaptionInput -InjectedInput
```

The click-isolation integration test needs a separate test-only engine. From
an x64 Native Tools Command Prompt:

```bat
cl /nologo /std:c++17 /EHsc /W4 /utf-8 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN /DNOMINMAX /DDUALCURSOR_TESTING /Fo:build\ /Fe:build\DualCursor-input-test.exe src\main.cpp src\devices.cpp src\overlay.cpp src\config.cpp /link /SUBSYSTEM:WINDOWS /ENTRY:wWinMainCRTStartup user32.lib gdi32.lib shell32.lib ole32.lib uuid.lib advapi32.lib
cl /nologo /std:c++17 /EHsc /W4 /utf-8 /DUNICODE /D_UNICODE /DNOMINMAX /Fo:build\automation_click_test.obj /Fe:build\automation_click_test.exe tests\automation_click_test.cpp user32.lib gdi32.lib
build\automation_click_test.exe build\DualCursor-input-test.exe
```

`DUALCURSOR_TESTING` exposes a simulated physical-seat input path for the test
harness. Never distribute this build. The normal build and packaging script
do not enable it. The test exercises both input paths against controlled click
targets; it does not certify compatibility with every game or macro program.

## Create the downloadable app

```powershell
.\package.ps1 -Version 0.1.0
```

This performs a fresh release build and creates a minimal ZIP plus its SHA-256
checksum under `dist`. It never includes logs, settings, tests, or debug builds.
See `docs/PUBLISHING.md` for the publication checklist.
