#!/usr/bin/env python3
"""Compatibility entrypoint: never package stale binaries."""
import runpy
from pathlib import Path
runpy.run_path(str(Path(__file__).with_name("build-release.py")),run_name="__main__")
