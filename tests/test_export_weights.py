#!/usr/bin/env python3
"""Smoke-test quantized NPZ -> VHDL conversion and CHW -> HWC reordering."""
from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess
import sys

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
EXPORTER = ROOT / "tools" / "export_weights.py"


def main():
    conv = np.zeros((4, 1, 3, 3), dtype=np.int8)
    conv_bias = np.zeros(4, dtype=np.int32)
    dense = np.zeros((10, 676), dtype=np.int8)
    dense_bias = np.zeros(10, dtype=np.int32)

    conv[0, 0, 0, 0] = 5
    conv_bias[0] = -9
    # CHW flattening: ch1/ch2/ch3 start at 169/338/507.
    dense[0, 0] = 1
    dense[0, 169] = 2
    dense[0, 338] = 3
    dense[0, 507] = 4
    dense_bias[0] = 10

    with TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        npz = tmp_path / "test_model.npz"
        output = tmp_path / "rtl"
        np.savez(npz, conv_weights=conv, conv_biases=conv_bias,
                 dense_weights=dense, dense_biases=dense_bias)
        subprocess.run([sys.executable, str(EXPORTER), str(npz),
                        "--out-dir", str(output)], check=True)

        c = (output / "cnn_weights_package.vhd").read_text(encoding="utf-8")
        d = (output / "dense_weights_package.vhd").read_text(encoding="utf-8")
        assert "to_signed(5, 8)" in c
        assert "to_signed(-9, 32)" in c
        for i, w in enumerate((1, 2, 3, 4)):
            assert f"{i} => to_signed({w}, 8)" in d
        assert "to_signed(10, 32)" in d

        work = tmp_path / "ghdl"
        work.mkdir()
        subprocess.run(["ghdl", "-a", "--std=08", f"--workdir={work}",
                        str(output / "cnn_weights_package.vhd"),
                        str(output / "dense_weights_package.vhd")], check=True)

    print("PASS: NPZ export, CHW->HWC mapping, generated VHDL syntax")


if __name__ == "__main__":
    main()
