from pathlib import Path

import numpy as np
import pytest

from sphynx.io import read_dlc, DlcData
from sphynx.exceptions import SphynxIOError

REPO = Path(__file__).resolve().parents[2]

SINGLE_CSV = (
    "scorer,DLC,DLC,DLC,DLC,DLC,DLC\n"
    "bodyparts,nose,nose,nose,tail,tail,tail\n"
    "coords,x,y,likelihood,x,y,likelihood\n"
    "0,100.5,200.25,0.987,110.1,210.7,0.93\n"
    "1,101.2,201.05,0.991,110.9,211.2,0.94\n"
    "2,102.05,202.3,0.988,111.0,212.8,0.95\n"
    "3,102.9,203.45,0.985,112.5,213.0,0.92\n"
    "4,103.7,204.15,0.989,113.1,214.6,0.91\n"
)


def _write(tmp_path, text):
    p = tmp_path / "dlc.csv"
    p.write_text(text)
    return p


def test_single_animal_parsed(tmp_path):
    out = read_dlc(_write(tmp_path, SINGLE_CSV))
    assert isinstance(out, DlcData)
    assert out.individuals is None
    assert out.selected_individual is None
    assert out.body_parts == ["nose", "tail"]
    assert out.n_frames == 5
    assert out.X[0, 0] == pytest.approx(100.5, abs=1e-6)
    assert out.Y[0, 0] == pytest.approx(200.25, abs=1e-6)
    assert out.likelihood[0, 0] == pytest.approx(0.987, abs=1e-6)
    assert not np.isnan(out.X).any()


def test_frame_range_slice(tmp_path):
    out = read_dlc(_write(tmp_path, SINGLE_CSV), start_frame=2, end_frame=4)
    assert out.n_frames == 3
    assert out.X[0, 0] == pytest.approx(101.2, abs=1e-6)  # 2nd data row


def test_negative_sentinel_becomes_nan(tmp_path):
    text = (
        "scorer,DLC,DLC,DLC\n"
        "bodyparts,nose,nose,nose\n"
        "coords,x,y,likelihood\n"
        "0,-1.0,-1.0,0.01\n"
        "1,50.0,60.0,0.99\n"
    )
    out = read_dlc(_write(tmp_path, text))
    assert np.isnan(out.X[0, 0])
    assert np.isnan(out.Y[0, 0])
    assert np.isnan(out.likelihood[0, 0])
    assert out.X[0, 1] == pytest.approx(50.0, abs=1e-6)


def test_missing_file_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        read_dlc(tmp_path / "nope.csv")


def test_malformed_column_count_raises(tmp_path):
    text = "scorer,DLC,DLC\nbodyparts,nose,nose\ncoords,x,y\n0,1.0,2.0\n"
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, text))


def test_non_numeric_data_cell_raises(tmp_path):
    text = (
        "scorer,DLC,DLC,DLC\n"
        "bodyparts,nose,nose,nose\n"
        "coords,x,y,likelihood\n"
        "0,foo,2.0,0.9\n"
    )
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, text))


def test_forced_individual_on_single_animal_csv_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, SINGLE_CSV), individual="animal3")


def test_start_frame_zero_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, SINGLE_CSV), start_frame=0)


def test_end_frame_negative_raises(tmp_path):
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, SINGLE_CSV), end_frame=-1)


def test_start_frame_past_end_of_data_raises(tmp_path):
    # SINGLE_CSV has 5 data rows; start_frame=100 is past end of data.
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, SINGLE_CSV), start_frame=100)


def test_ragged_multi_animal_header_raises(tmp_path):
    # individuals row has fewer tokens than bodyparts row -> ragged header.
    text = (
        "scorer,DLC,DLC,DLC,DLC,DLC,DLC\n"
        "individuals,animal1,animal1,animal1\n"
        "bodyparts,nose,nose,nose,tail,tail,tail\n"
        "coords,x,y,likelihood,x,y,likelihood\n"
        "0,100.5,200.25,0.987,110.1,210.7,0.93\n"
    )
    with pytest.raises(SphynxIOError):
        read_dlc(_write(tmp_path, text))


def test_multi_animal_stfp_selects_true_animal():
    csv = REPO / "Demo" / "DLC" / (
        "Stfp 1 D5 T2 1-14-1DLC_resnet50_STFP_2T_1GJun13shuffle1_100000_el.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo STFP el.csv not present")
    out = read_dlc(csv)
    assert out.individuals is not None
    assert "observer" in out.individuals
    assert "demonstrator" in out.individuals
    assert "single" in out.individuals
    assert out.selected_individual in ("observer", "demonstrator")
    assert len(out.body_parts) == 11


def test_multi_animal_barnes_sentinel_and_pick():
    csv = REPO / "Demo" / "BARNES" / "3_DLC" / (
        "2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo BARNES snapshot csv not present")
    out = read_dlc(csv)
    assert len(out.individuals) == 10
    assert out.selected_individual.startswith("animal")
    assert len(out.body_parts) == 27
    assert np.isnan(out.X).any()
    assert int((~np.isnan(out.X) & ~np.isnan(out.Y)).sum()) > 0


def test_forced_individual():
    csv = REPO / "Demo" / "BARNES" / "3_DLC" / (
        "2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo BARNES snapshot csv not present")
    out = read_dlc(csv, individual="animal3")
    assert out.selected_individual == "animal3"


def test_forced_unknown_individual_raises():
    csv = REPO / "Demo" / "BARNES" / "3_DLC" / (
        "2024_11_02_17_16_42_test_cr_reencoded_superanimal_topviewmouse_snapshot.csv"
    )
    if not csv.is_file():
        pytest.skip("Demo BARNES snapshot csv not present")
    with pytest.raises(SphynxIOError):
        read_dlc(csv, individual="nobody")
