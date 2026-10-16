"""Text simulator for the common path model."""

from .geometry import Path, Segment


def describe(paths):
    lines = ["SIMULATION ONLY — no serial transmission"]
    for index, path in enumerate(paths, 1):
        points = path.flatten()
        lines.append("path %d: %d points, bounds=%s" %
                     (index, len(points), path.bounds()))
        for point in points:
            lines.append("  CUT %.3f,%.3f" % point)
    return "\n".join(lines)


def demo():
    path = Path([Segment("line", ((0, 0), (50, 0))),
                 Segment("line", ((50, 0), (50, 50))),
                 Segment("line", ((50, 50), (0, 50))),
                 Segment("line", ((0, 50), (0, 0)))], closed=True)
    print(describe([path]))


if __name__ == "__main__":
    demo()
