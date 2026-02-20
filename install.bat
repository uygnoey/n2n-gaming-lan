@echo off
chcp 65001 >nul 2>&1

net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

pushd "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_edge.ps1"
popd
pause
