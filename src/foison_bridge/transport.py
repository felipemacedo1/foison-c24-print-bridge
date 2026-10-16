"""Transport boundary with safe simulation and validated serial settings."""

from dataclasses import dataclass
from enum import Enum
from typing import Callable, Optional


class FlowControl(str, Enum):
    NONE = "None"
    XON_XOFF = "Xon/Xoff"
    RTS_CTS = "RTS/CTS"


@dataclass(frozen=True)
class SerialConfig:
    port: str = "COM2"
    baud_rate: int = 38400
    data_bits: int = 8
    parity: str = "None"
    stop_bits: int = 1
    flow_control: FlowControl = FlowControl.XON_XOFF
    simulation_mode: bool = True
    physical_cut_enabled: bool = False

    def validate(self):
        if not self.port or not self.port.upper().startswith("COM"):
            raise ValueError("port must be a COM device")
        if self.baud_rate <= 0 or self.data_bits not in (7, 8):
            raise ValueError("invalid serial framing")
        if self.parity not in ("None", "Even", "Odd"):
            raise ValueError("unsupported parity")
        if self.stop_bits not in (1, 2):
            raise ValueError("unsupported stop bits")
        if self.physical_cut_enabled and self.simulation_mode:
            raise ValueError("physical cut cannot be enabled in simulation mode")


class TransportError(RuntimeError):
    """Raised when a transport cannot accept a job."""


class SafeTransport:
    """Injectable transport; default operation records data without sending."""

    def __init__(self, config: SerialConfig,
                 writer: Optional[Callable[[bytes], int]] = None):
        config.validate()
        self.config = config
        self._writer = writer
        self.sent_bytes = 0

    def send(self, payload: bytes) -> int:
        if not payload:
            raise TransportError("cannot send an empty payload")
        if not self.config.simulation_mode and not self.config.physical_cut_enabled:
            raise TransportError("physical cut is not explicitly enabled")
        if self.config.simulation_mode:
            self.sent_bytes += len(payload)
            return len(payload)
        if self._writer is None:
            raise TransportError("no serial writer configured")
        written = self._writer(payload)
        self.sent_bytes += written
        if written != len(payload):
            raise TransportError("serial writer accepted a partial payload")
        return written


class JobQueue:
    """Single-worker queue state machine; physical jobs never run concurrently."""

    def __init__(self):
        self._active = None
        self._pending = []

    def enqueue(self, job_id: str):
        if not job_id:
            raise ValueError("job_id is required")
        self._pending.append((job_id, "queued"))

    def start_next(self) -> str:
        if self._active is not None:
            raise TransportError("a job is already active")
        if not self._pending:
            raise TransportError("no pending jobs")
        job_id, _ = self._pending.pop(0)
        self._active = (job_id, "transmitting")
        return job_id

    def finish(self, success: bool):
        if self._active is None:
            raise TransportError("no active job")
        job_id = self._active[0]
        self._active = None
        return job_id, "completed" if success else "failed"

    def cancel_pending(self, job_id: str) -> bool:
        for index, item in enumerate(self._pending):
            if item[0] == job_id:
                del self._pending[index]
                return True
        return False
