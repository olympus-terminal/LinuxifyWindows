@echo off
rem Double-click: opens an admin PowerShell and runs linuxify.ps1 from this folder
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0linuxify.ps1\"'"
