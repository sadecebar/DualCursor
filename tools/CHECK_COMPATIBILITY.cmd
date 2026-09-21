@echo off
cd /d "%~dp0.."
echo DualCursor compatibility test 1 of 2...
DualCursor.exe --probe
echo.
echo DualCursor compatibility test 2 of 2...
DualCursor.exe --probe-echo
echo.
echo Test finished. Read the result above, then press any key.
pause >nul
