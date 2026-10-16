"""Small, dependency-free geometry model used by the simulator and adapters."""

from dataclasses import dataclass
from math import hypot
from typing import Iterable, List, Tuple

Point = Tuple[float, float]


@dataclass(frozen=True)
class Affine:
    a: float = 1.0
    b: float = 0.0
    c: float = 0.0
    d: float = 1.0
    e: float = 0.0
    f: float = 0.0

    def apply(self, point: Point) -> Point:
        x, y = point
        return (self.a * x + self.c * y + self.e,
                self.b * x + self.d * y + self.f)


@dataclass(frozen=True)
class Segment:
    kind: str
    points: Tuple[Point, ...]


@dataclass
class Path:
    segments: List[Segment]
    closed: bool = False

    def transformed(self, matrix: Affine) -> "Path":
        return Path(
            [Segment(segment.kind, tuple(matrix.apply(p) for p in segment.points))
             for segment in self.segments],
            self.closed,
        )

    def flatten(self, tolerance: float = 0.1) -> List[Point]:
        if tolerance <= 0:
            raise ValueError("tolerance must be positive")
        result: List[Point] = []
        for segment in self.segments:
            if segment.kind == "line":
                if not result:
                    result.append(segment.points[0])
                result.append(segment.points[1])
            elif segment.kind == "cubic":
                start, c1, c2, end = segment.points
                curve = _flatten_cubic(start, c1, c2, end, tolerance)
                if result:
                    result.extend(curve[1:])
                else:
                    result.extend(curve)
            else:
                raise ValueError("unsupported segment kind: %s" % segment.kind)
        if self.closed and result and result[-1] != result[0]:
            result.append(result[0])
        return result

    def bounds(self) -> Tuple[float, float, float, float]:
        points = self.flatten()
        if not points:
            raise ValueError("empty path")
        xs, ys = zip(*points)
        return min(xs), min(ys), max(xs), max(ys)


def _flat_enough(p0: Point, p1: Point, p2: Point, p3: Point,
                 tolerance: float) -> bool:
    def distance(point: Point, start: Point, end: Point) -> float:
        dx, dy = end[0] - start[0], end[1] - start[1]
        if dx == dy == 0:
            return hypot(point[0] - start[0], point[1] - start[1])
        return abs(dy * point[0] - dx * point[1] + end[0] * start[1]
                   - end[1] * start[0]) / hypot(dx, dy)
    return max(distance(p1, p0, p3), distance(p2, p0, p3)) <= tolerance


def _split_cubic(points: Tuple[Point, Point, Point, Point]):
    p0, p1, p2, p3 = points
    def mid(left: Point, right: Point) -> Point:
        return ((left[0] + right[0]) / 2, (left[1] + right[1]) / 2)
    q0, q1, q2 = mid(p0, p1), mid(p1, p2), mid(p2, p3)
    r0, r1 = mid(q0, q1), mid(q1, q2)
    center = mid(r0, r1)
    return (p0, q0, r0, center), (center, r1, q2, p3)


def _flatten_cubic(p0: Point, p1: Point, p2: Point, p3: Point,
                   tolerance: float) -> List[Point]:
    stack = [(p0, p1, p2, p3, 0)]
    output: List[Point] = []
    while stack:
        a, b, c, d, depth = stack.pop()
        if _flat_enough(a, b, c, d, tolerance) or depth >= 16:
            if not output:
                output.append(a)
            output.append(d)
            continue
        left, right = _split_cubic((a, b, c, d))
        stack.append((*right, depth + 1))
        stack.append((*left, depth + 1))
    return output
