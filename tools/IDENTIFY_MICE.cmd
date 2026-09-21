@echo off
cd /d "%~dp0.."
echo Follow the instructions in the new window.
echo Move only the requested mouse, then press Enter.
DualCursor.exe --identify
pause
