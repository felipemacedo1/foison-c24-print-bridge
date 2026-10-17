#requires -version 2.0
# Compatibility entrypoint retained for existing CI and manual instructions.
& (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'process-runner.ps1')
if (-not $?) { exit 1 }
