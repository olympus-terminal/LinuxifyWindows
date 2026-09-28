@echo off
rem Double-click: opens an admin PowerShell and runs undo-linuxify.ps1 from this folder
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0undo-linuxify.ps1\"'"
