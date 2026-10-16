"""Experimental HPGL serializer; protocol and units are not yet validated."""

from .geometry import Path


def serialize(paths, units_per_mm: float, origin=(0.0, 0.0)) -> str:
    if units_per_mm <= 0:
        raise ValueError("units_per_mm must be positive")
    commands = ["IN;"]
    ox, oy = origin
    for path in paths:
        points = path.flatten()
        if not points:
            continue
        first = _point(points[0], units_per_mm, ox, oy)
        commands.append("PU%d,%d;" % first)
        for point in points[1:]:
            commands.append("PD%d,%d;" % _point(point, units_per_mm, ox, oy))
        commands.append("PU;")
    commands.append("SP0;")
    return "".join(commands)


def _point(point, scale, ox, oy):
    return round((point[0] + ox) * scale), round((point[1] + oy) * scale)
