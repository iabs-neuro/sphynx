import numpy as np

from sphynx.preset import mask_from_border


def test_marks_rounded_pixels():
    m = mask_from_border(10, 10, [3.4, 5.7], [2.1, 8.6])
    assert m[1, 2]   # round(2.1)=2 row, round(3.4)=3 col -> 0-based [1,2]
    assert m[8, 5]   # round(8.6)=9 row, round(5.7)=6 col -> 0-based [8,5]
    assert m.sum() == 2


def test_skips_out_of_bounds():
    m = mask_from_border(10, 10, [0, 11, 5], [5, 5, 12])
    assert m.sum() == 0
