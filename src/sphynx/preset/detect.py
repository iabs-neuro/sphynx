"""Find the objects inside an arena automatically (S4h).

Port of matlab/+sphynx/+preset/autoDetectObjects.m. Objects are darker than
the arena floor, so the image is thresholded locally, the blobs inside the
arena are kept, and each is turned into an outline of the requested shape.

WHAT THIS IS NOT: a measurement. Every detection lands on the canvas as an
ordinary drawn shape, which the experimenter sees, moves, deletes or replaces
before anything is built from it. That is why the local threshold below is a
faithful reimplementation of MATLAB's SEMANTICS rather than of its arithmetic:
`adaptthresh`'s sensitivity curve is not documented, and a proposal the user
inspects can differ where a zone geometry could not.

`detect_objects` returns proposals; it never mutates a preset.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from scipy.ndimage import (
    binary_opening, distance_transform_edt, find_objects, label, uniform_filter,
)

from sphynx.exceptions import SphynxValueError
from sphynx.util.geometry import circle_fit

MODES = ("free-form", "all-circles", "all-polygons", "all-ellipses")
ALGORITHMS = ("threshold", "hough")

# No single object may cover more than half the arena: a blob that large is
# the floor, the lighting, or the animal -- never an object.
_MAX_ARENA_FRACTION = 0.5
_OUTLINE_POINTS = 60


@dataclass
class Detection:
    """One proposed object, in frame pixel coordinates."""

    geometry: str                       # Circle | Ellipse | Polygon
    x: np.ndarray                       # outline, closed implicitly
    y: np.ndarray
    mask: np.ndarray
    area_px: int = 0
    metadata: dict = field(default_factory=dict)


def _as_gray_uint8(frame) -> np.ndarray:
    frame = np.asarray(frame)
    if frame.ndim == 3:
        # Rec. 601 luma, the same weights rgb2gray uses.
        frame = (0.2989 * frame[..., 0] + 0.5870 * frame[..., 1]
                 + 0.1140 * frame[..., 2])
    if frame.ndim != 2:
        raise SphynxValueError(
            f"a frame is a 2-D or 3-D image; got shape {np.shape(frame)}")
    if frame.dtype == np.uint8:
        return frame
    values = np.asarray(frame, dtype=float)
    if values.max() <= 1.0:
        values = values * 255.0
    return np.clip(values, 0, 255).astype(np.uint8)


def _disk(radius: int) -> np.ndarray:
    radius = max(int(radius), 1)
    ys, xs = np.mgrid[-radius : radius + 1, -radius : radius + 1]
    return (xs**2 + ys**2) <= radius**2


def local_threshold(gray, sensitivity: float, neighborhood_px: int = 0):
    """A per-pixel threshold in 0..1, brighter neighbourhoods thresholding higher.

    Stands in for MATLAB's `adaptthresh(I, sensitivity)`: a local mean scaled
    so that a higher sensitivity admits more foreground. Not bit-identical --
    see the module docstring for why that is acceptable here."""
    if not 0.0 <= sensitivity <= 1.0:
        raise SphynxValueError(
            f"sensitivity must be between 0 and 1; got {sensitivity}")
    gray = np.asarray(gray, dtype=float) / 255.0
    if neighborhood_px and neighborhood_px > 0:
        size = max(3, int(neighborhood_px) | 1)          # odd, at least 3
    else:
        # adaptthresh's own default neighbourhood: 1/16 of the image, odd.
        size = max(3, (2 * int(np.floor(max(gray.shape) / 16)) + 1))
    local_mean = uniform_filter(gray, size=size, mode="reflect")
    # sensitivity 0.5 keeps the plain local mean; higher raises the bar so
    # more pixels fall below it and count as (dark) object.
    return np.clip(local_mean * (1.0 + (sensitivity - 0.5)), 0.0, 1.0)


def _perimeter(bx, by) -> float:
    return float(np.hypot(np.diff(bx), np.diff(by)).sum())


def _outline_of_component(component, mode, stats):
    """The requested outline for one connected component."""
    from skimage.measure import approximate_polygon, find_contours

    # A blob cropped to its own bounding box touches all four edges, and a
    # contour that runs off the array is returned open -- it would trace only
    # part of the outline and pull the filled mask off the object. One ring of
    # background around it keeps every contour closed.
    padded = np.pad(component.astype(float), 1)
    contours = find_contours(padded, 0.5)
    if not contours:
        return None
    # find_contours returns (row, col); the canvas speaks (x, y).
    contour = max(contours, key=len)
    bx, by = contour[:, 1] - 1.0, contour[:, 0] - 1.0

    if mode in ("free-form", "all-polygons"):
        # A traced outline at full resolution has thousands of vertices. Both
        # filling it (cost = pixels x vertices) and storing it as a canvas
        # polygon then cost far more than the shape is worth -- one real frame
        # spent 50 s in a single fill. MATLAB does not pay this because imfill
        # rasterises in linear time whatever the vertex count.
        #
        # 'all-polygons' asks for a deliberately coarse outline, as there;
        # 'free-form' is simplified only to within a pixel, which no one can
        # see and which leaves the shape editable.
        tolerance = 0.02 * _perimeter(bx, by) if mode == "all-polygons" else 1.0
        reduced = approximate_polygon(np.column_stack([bx, by]), tolerance)
        if len(reduced) >= 3:
            bx, by = reduced[:, 0], reduced[:, 1]
        return "Polygon", bx, by
    if mode == "all-circles":
        try:
            cx, cy, radius = circle_fit(bx, by)
        except Exception:                              # noqa: BLE001
            return None
        angle = np.linspace(0.0, 2.0 * np.pi, _OUTLINE_POINTS)
        return "Circle", cx + radius * np.cos(angle), cy + radius * np.sin(angle)
    if mode == "all-ellipses":
        angle = np.linspace(0.0, 2.0 * np.pi, _OUTLINE_POINTS)
        major = stats["major_axis"] * stats["semi_major"]
        minor = stats["minor_axis"] * stats["semi_minor"]
        offset = (np.cos(angle)[:, None] * major
                  + np.sin(angle)[:, None] * minor)
        return ("Ellipse", stats["cx"] + offset[:, 0], stats["cy"] + offset[:, 1])
    raise SphynxValueError(f"unknown mode {mode!r}; expected one of {MODES}")


def _mask_from_outline(bx, by, height, width) -> np.ndarray:
    """Fill an outline into a full-frame mask.

    Only the outline's own bounding box is rasterized. Testing every pixel of
    the frame instead costs the full frame area PER detection -- on a 1340x1172
    clip with a few dozen blobs that is minutes, and the button reads as
    hung."""
    from matplotlib.path import Path as MplPath

    mask = np.zeros((height, width), dtype=bool)
    if len(bx) < 3:
        return mask
    x0 = max(int(np.floor(np.min(bx))), 0)
    x1 = min(int(np.ceil(np.max(bx))) + 1, width)
    y0 = max(int(np.floor(np.min(by))), 0)
    y1 = min(int(np.ceil(np.max(by))) + 1, height)
    if x1 <= x0 or y1 <= y0:
        return mask                     # entirely off the frame

    grid_y, grid_x = np.mgrid[y0:y1, x0:x1]
    points = np.column_stack([grid_x.ravel(), grid_y.ravel()])
    inside = MplPath(np.column_stack([bx, by])).contains_points(points)
    mask[y0:y1, x0:x1] = inside.reshape(y1 - y0, x1 - x0)
    return mask


def _area_bounds(min_area_cm2, max_area_cm2, pixels_per_cm, arena_area):
    if pixels_per_cm is None or pixels_per_cm <= 0:
        raise SphynxValueError(
            "pixels_per_cm is required: the area filters are in square "
            "centimetres and mean nothing without it")
    if min_area_cm2 < 0 or max_area_cm2 <= 0 or max_area_cm2 < min_area_cm2:
        raise SphynxValueError(
            f"the area range must be 0 <= min <= max and max > 0; got "
            f"{min_area_cm2}..{max_area_cm2} cm^2")
    scale = float(pixels_per_cm) ** 2
    lowest = min_area_cm2 * scale
    highest = min(max_area_cm2 * scale, arena_area * _MAX_ARENA_FRACTION)
    return lowest, highest


def _detect_hough(gray, arena_mask, radius_range_px, sensitivity, bounds):
    from skimage.transform import hough_circle, hough_circle_peaks
    from skimage.feature import canny

    lowest, highest = bounds
    height, width = arena_mask.shape
    r_min, r_max = (max(1, int(round(radius_range_px[0]))),
                    max(2, int(round(radius_range_px[1]))))
    if r_max <= r_min:
        raise SphynxValueError(
            f"the radius range must increase; got {r_min}..{r_max} px")
    # Objects are dark on a lighter floor (ObjectPolarity 'dark' in MATLAB),
    # so edges are found on the inverted image.
    edges = canny(255 - gray, sigma=2.0)
    radii = np.arange(r_min, r_max + 1, max(1, (r_max - r_min) // 20 or 1))
    accumulator = hough_circle(edges, radii)
    # The peak threshold follows sensitivity the way imfindcircles' does:
    # a higher sensitivity accepts weaker accumulator peaks.
    _, cxs, cys, found_radii = hough_circle_peaks(
        accumulator, radii, total_num_peaks=20,
        threshold=max(0.05, 1.0 - float(sensitivity)))

    out = []
    for cx, cy, radius in zip(cxs, cys, found_radii):
        row = int(np.clip(round(cy), 0, height - 1))
        column = int(np.clip(round(cx), 0, width - 1))
        if not arena_mask[row, column]:
            continue
        angle = np.linspace(0.0, 2.0 * np.pi, _OUTLINE_POINTS)
        bx, by = cx + radius * np.cos(angle), cy + radius * np.sin(angle)
        mask = _mask_from_outline(bx, by, height, width)
        area = int(mask.sum())
        if area < lowest or area > highest:
            continue
        out.append(Detection("Circle", bx, by, mask, area))
    return out


def detect_objects(frame, arena_mask, pixels_per_cm, mode: str = "free-form",
                   algorithm: str = "threshold", sensitivity: float = 0.75,
                   min_area_cm2: float = 1.0, max_area_cm2: float = 200.0,
                   neighborhood_cm: float = 0.0,
                   radius_range_cm=(1.0, 10.0)) -> list:
    """Propose the objects lying inside `arena_mask`.

    Returns a list of `Detection`; an empty list means nothing matched, which
    is a result, not a failure."""
    if mode not in MODES:
        raise SphynxValueError(f"unknown mode {mode!r}; expected one of {MODES}")
    if algorithm not in ALGORITHMS:
        raise SphynxValueError(
            f"unknown algorithm {algorithm!r}; expected one of {ALGORITHMS}")

    arena = np.asarray(arena_mask) > 0
    if not arena.any():
        return []
    gray = _as_gray_uint8(frame)
    if gray.shape != arena.shape:
        raise SphynxValueError(
            f"the frame is {gray.shape} but the arena mask is {arena.shape}")

    bounds = _area_bounds(min_area_cm2, max_area_cm2, pixels_per_cm,
                          int(arena.sum()))

    if mode == "all-circles" and algorithm == "hough":
        radius_px = (radius_range_cm[0] * pixels_per_cm,
                     radius_range_cm[1] * pixels_per_cm)
        return _detect_hough(gray, arena, radius_px, sensitivity, bounds)

    # Shrink the arena by ~1 cm so a darkened boundary ring is not returned
    # as a blob hugging the wall. Eroding with a disk structuring element is
    # what MATLAB writes, but at 22 px/cm that is a 45x45 element over a
    # 1.6-megapixel frame and it dominates the whole call; the distance
    # transform gives the same set of pixels in one linear pass.
    erosion_px = max(3.0, float(pixels_per_cm))
    eroded = distance_transform_edt(arena) > erosion_px
    if not eroded.any():
        eroded = arena          # arena too small to erode; use it as drawn

    # A floor-relative ceiling on top of the local threshold: on a flat
    # synthetic background the local mean tracks the floor exactly and would
    # otherwise mark half of it as object.
    floor_level = np.percentile(gray[arena].astype(float), 75)
    floor_fraction = 1.0 - (1.0 - sensitivity) * 0.4
    floor_threshold = floor_level / 255.0 * floor_fraction

    neighborhood_px = (int(round(neighborhood_cm * pixels_per_cm))
                       if neighborhood_cm and neighborhood_cm > 0 else 0)
    threshold = np.minimum(
        local_threshold(gray, sensitivity, neighborhood_px), floor_threshold)
    dark = (gray / 255.0) <= threshold
    blobs = binary_opening(dark & eroded, _disk(2))

    labels, count = label(blobs)
    lowest, highest = bounds
    height, width = arena.shape
    # Each blob is handled inside its own bounding box. Materialising a
    # full-frame mask per component instead makes every step cost the whole
    # frame, however small the object.
    boxes = find_objects(labels)
    out = []
    for index, box in enumerate(boxes, start=1):
        if box is None:
            continue
        local = labels[box] == index
        area = int(local.sum())
        if area < lowest or area > highest:
            continue
        top, left = box[0].start, box[1].start
        ys, xs = np.nonzero(local)
        cx, cy = xs.mean() + left, ys.mean() + top
        row = int(np.clip(round(cy), 0, height - 1))
        column = int(np.clip(round(cx), 0, width - 1))
        if not arena[row, column]:
            continue

        outline = _outline_of_component(
            local, mode, _shape_stats(local, cx - left, cy - top))
        if outline is None:
            continue
        geometry, bx, by = outline
        bx, by = np.asarray(bx) + left, np.asarray(by) + top
        mask = _mask_from_outline(bx, by, height, width)
        if not mask.any():
            continue
        out.append(Detection(geometry, np.asarray(bx), np.asarray(by), mask,
                             int(mask.sum())))
    return out


def _shape_stats(component, cx, cy) -> dict:
    """The best-fit ellipse of a blob, from the eigenvectors of its covariance.

    MATLAB reads regionprops' MajorAxisLength/MinorAxisLength/Orientation and
    then rebuilds the ellipse from them, which means matching two sign
    conventions (regionprops' and the image y-axis). The eigen-decomposition
    is the same ellipse without either: for a filled ellipse of semi-axes
    a and b the covariance eigenvalues are a^2/4 and b^2/4."""
    ys, xs = np.nonzero(component)
    coords = np.vstack([xs - cx, ys - cy])
    # The 1/12 diagonal term is the finite-pixel-size correction regionprops
    # applies; without it a one-pixel-wide blob has zero width.
    covariance = np.cov(coords) + np.eye(2) / 12.0
    values, vectors = np.linalg.eigh(covariance)
    order = np.argsort(values)[::-1]                 # major axis first
    values, vectors = values[order], vectors[:, order]
    semi = 2.0 * np.sqrt(np.maximum(values, 0.0))
    return {"cx": cx, "cy": cy,
            "semi_major": float(semi[0]), "semi_minor": float(semi[1]),
            "major_axis": vectors[:, 0], "minor_axis": vectors[:, 1]}
