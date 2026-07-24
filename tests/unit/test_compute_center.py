import numpy as np

from sphynx.bodyparts import compute_center, Point


def test_center_takes_precedence():
    bpx = np.array([[1.0, 2, 3], [10, 20, 30], [100, 200, 300]])
    bpy = np.array([[4.0, 5, 6], [40, 50, 60], [400, 500, 600]])
    p = Point(center=1, left_body_center=0, right_body_center=2)
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [10, 20, 30])
    assert np.array_equal(yc, [40, 50, 60])


def test_falls_back_to_left_right_mean():
    bpx = np.array([[10.0, 20, 30], [30, 40, 50]])
    bpy = np.array([[5.0, 6, 7], [15, 16, 17]])
    p = Point(center=None, left_body_center=0, right_body_center=1)
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [20, 30, 40])
    assert np.array_equal(yc, [10, 11, 12])


def test_synthetic_mean_when_none():
    bpx = np.array([[1.0, 2, 3], [3, 4, 5], [5, 6, 7]])
    bpy = np.array([[10.0, 20, 30], [30, 40, 50], [50, 60, 70]])
    p = Point()
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [3, 4, 5])
    assert np.array_equal(yc, [30, 40, 50])


def test_nan_ignored_in_synthetic_mean():
    bpx = np.array([[np.nan, 2, 3], [3, 4, 5], [5, 6, np.nan]])
    bpy = np.array([[10.0, 20, 30], [30, 40, 50], [50, 60, 70]])
    xc, yc = compute_center(bpx, bpy, Point())
    assert np.array_equal(xc, [4, 4, 4])
    assert np.array_equal(yc, [30, 40, 50])


def test_empty_returns_empty():
    xc, yc = compute_center(np.array([]), np.array([]), Point())
    assert xc.size == 0 and yc.size == 0


def test_only_one_of_left_right_falls_through():
    bpx = np.array([[2.0, 4, 6], [8, 10, 12]])
    bpy = np.array([[1.0, 3, 5], [7, 9, 11]])
    p = Point(left_body_center=0, right_body_center=None)
    xc, yc = compute_center(bpx, bpy, p)
    assert np.array_equal(xc, [5, 7, 9])
    assert np.array_equal(yc, [4, 6, 8])
