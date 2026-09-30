@echo off
rem Double-click: opens an admin PowerShell and runs gaming\game-tune.ps1 from this folder
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0gaming\game-tune.ps1\"'"
