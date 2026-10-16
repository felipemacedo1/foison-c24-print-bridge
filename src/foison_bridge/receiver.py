"""Capture a redirected print stream without interpreting or executing it."""

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

MAX_DEFAULT = 64 * 1024 * 1024


def detect_format(data: bytes) -> str:
    if data.startswith(b"%!PS-"):
        return "postscript"
    if data.startswith(b"\x1b%-12345X"):
        return "pcl/ujf"
    return "unknown"


def capture(data: bytes, output_dir: Path, max_bytes: int = MAX_DEFAULT):
    if not data:
        raise ValueError("empty print stream")
    if len(data) > max_bytes:
        raise ValueError("print stream exceeds configured size limit")
    fmt = detect_format(data)
    if fmt == "unknown":
        raise ValueError("unsupported or unknown print stream format")
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S", time.gmtime())
    job_id = "%s-%s" % (stamp, hashlib.sha256(data).hexdigest()[:12])
    raw_path = output_dir / ("job-%s.raw" % job_id)
    report_path = output_dir / ("job-%s.json" % job_id)
    raw_path.write_bytes(data)
    report = {
        "job_id": job_id,
        "format": fmt,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "simulation_mode": True,
        "physical_cut_enabled": False,
        "status": "captured",
    }
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--max-bytes", type=int, default=MAX_DEFAULT)
    args = parser.parse_args(argv)
    try:
        report = capture(sys.stdin.buffer.read(args.max_bytes + 1),
                         args.output_dir, args.max_bytes)
    except (OSError, ValueError) as error:
        print("capture failed: %s" % error, file=sys.stderr)
        return 2
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
