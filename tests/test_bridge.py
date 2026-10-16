import json
import tempfile
import unittest
from pathlib import Path

from foison_bridge.geometry import Affine, Path as CutPath, Segment
from foison_bridge.hpgl import serialize
from foison_bridge.receiver import capture, detect_format
from foison_bridge.transport import JobQueue, SafeTransport, SerialConfig, TransportError


class ReceiverTests(unittest.TestCase):
    def test_detects_postscript_and_rejects_unknown(self):
        self.assertEqual(detect_format(b"%!PS-Adobe-3.0\n"), "postscript")
        self.assertEqual(detect_format(b"not a print job"), "unknown")

    def test_capture_writes_raw_and_report(self):
        with tempfile.TemporaryDirectory() as directory:
            report = capture(b"%!PS-Adobe-3.0\n%%EOF\n", Path(directory))
            self.assertEqual(report["format"], "postscript")
            files = list(Path(directory).iterdir())
            self.assertEqual(len(files), 2)
            saved = json.loads(next(p for p in files if p.suffix == ".json").read_text())
            self.assertEqual(saved["sha256"], report["sha256"])

    def test_capture_rejects_limit_and_empty(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                capture(b"", Path(directory))
            with self.assertRaises(ValueError):
                capture(b"%!PS-Adobe-3.0", Path(directory), max_bytes=4)


class GeometryTests(unittest.TestCase):
    def test_transform_and_bounds(self):
        path = CutPath([Segment("line", ((0, 0), (10, 5)))])
        moved = path.transformed(Affine(e=2, f=-3))
        self.assertEqual(moved.bounds(), (2, -3, 12, 2))

    def test_bezier_is_flattened_and_closed(self):
        path = CutPath([Segment("cubic", ((0, 0), (0, 10), (10, 10), (10, 0)))],
                       closed=True)
        points = path.flatten(0.2)
        self.assertGreater(len(points), 3)
        self.assertEqual(points[0], points[-1])

    def test_hpgl_is_deterministic(self):
        path = CutPath([Segment("line", ((0, 0), (1.2, 2.6)))])
        self.assertEqual(serialize([path], 10), "IN;PU0,0;PD12,26;PU;SP0;")


class TransportTests(unittest.TestCase):
    def test_default_transport_is_simulation_only(self):
        transport = SafeTransport(SerialConfig())
        self.assertEqual(transport.send(b"IN;"), 3)
        self.assertEqual(transport.sent_bytes, 3)

    def test_physical_transport_requires_writer_and_explicit_flag(self):
        config = SerialConfig(simulation_mode=False, physical_cut_enabled=True)
        with self.assertRaises(TransportError):
            SafeTransport(config).send(b"PU0,0;")

    def test_queue_allows_only_one_active_job(self):
        queue = JobQueue()
        queue.enqueue("one")
        queue.enqueue("two")
        self.assertEqual(queue.start_next(), "one")
        with self.assertRaises(TransportError):
            queue.start_next()
        self.assertEqual(queue.finish(True), ("one", "completed"))
        self.assertTrue(queue.cancel_pending("two"))


if __name__ == "__main__":
    unittest.main()
