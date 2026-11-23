#!/usr/bin/env python3
"""Export already-quantized CNN weights into VHDL packages.

Input NPZ keys:
  conv_weights: int8 (4,3,3) or (4,1,3,3)
  conv_biases:  int32 (4,)
  dense_weights: int8 (10,676) or (10,4,13,13)
  dense_biases: int32 (10,)

For (10,676) the default layout is PyTorch/CHW flatten order.
The AXI stream is pixel-major HWC, so weights are transposed accordingly.
This script does not perform training, calibration or quantization.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np

OUT_WIDTH = 13
OUT_HEIGHT = 13
CHANNELS = 4
FEATURES = OUT_WIDTH * OUT_HEIGHT * CHANNELS
CLASSES = 10


def check_int(a: np.ndarray, name: str, lo: int, hi: int) -> np.ndarray:
    if not np.issubdtype(a.dtype, np.integer):
        raise ValueError(f"{name} must be quantized integer values, got {a.dtype}")
    if a.size == 0 or a.min() < lo or a.max() > hi:
        raise ValueError(f"{name} outside range [{lo}, {hi}]")
    return a.astype(np.int64)


def signed(value: int, bits: int) -> str:
    return f"to_signed({int(value)}, {bits})"


def conv_package(w: np.ndarray, b: np.ndarray) -> str:
    entries = []
    for k in range(CHANNELS):
        vals = ", ".join(signed(x, 8) for x in w[k].reshape(-1))
        entries.append(f"    {k} => ({vals})")
    biases = ",\n".join(f"    {k} => {signed(b[k],32)}"
                         for k in range(CHANNELS))
    lines = ",\n".join(entries)
    return f"""library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package cnn_weights_pkg is
  type kernel_t is array (0 to 8) of signed(7 downto 0);
  type filters_t is array (0 to 3) of kernel_t;
  constant CONV_WEIGHTS : filters_t := (
{lines}
  );
  type biases_t is array (0 to 3) of signed(31 downto 0);
  constant CONV_BIASES : biases_t := (
{biases}
  );
end package;
"""


def dense_package(w: np.ndarray, b: np.ndarray) -> str:
    rows = []
    for klass in range(CLASSES):
        vals = ",\n        ".join(
            f"{feature_idx} => {signed(weight,8)}"
            for feature_idx, weight in enumerate(w[klass])
            if weight != 0
        )
        if vals:
            rows.append(f"    {klass} => (\n        {vals},\n        others => to_signed(0, 8)\n    )")
        else:
            rows.append(f"    {klass} => (others => to_signed(0, 8))")
    biases = ",\n".join(f"    {k} => {signed(b[k],32)}" for k in range(CLASSES))
    lines = ",\n".join(rows)
    return f"""library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dense_weights_pkg is
  constant NUM_CLASSES : positive := 10;
  constant MAX_INPUT_FEATURES : positive := 676;
  type dense_row_t is array (0 to MAX_INPUT_FEATURES-1) of signed(7 downto 0);
  type dense_matrix_t is array (0 to NUM_CLASSES-1) of dense_row_t;
  type dense_bias_t is array (0 to NUM_CLASSES-1) of signed(31 downto 0);
  constant DENSE_WEIGHTS : dense_matrix_t := (
{lines}
  );
  constant DENSE_BIASES : dense_bias_t := (
{biases}
  );
end package;
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("npz", type=Path, help="already-quantized weights .npz")
    parser.add_argument("--dense-layout", choices=["chw", "hwc"], default="chw",
                        help="flatten layout for 2D (10,676) dense weights")
    parser.add_argument("--out-dir", type=Path,
                        default=Path(__file__).resolve().parent.parent / "rtl")
    args = parser.parse_args()

    with np.load(args.npz, allow_pickle=False) as data:
        for name in ("conv_weights", "conv_biases",
                     "dense_weights", "dense_biases"):
            if name not in data:
                raise ValueError(f"Missing NPZ key: {name}")
        conv = check_int(data["conv_weights"], "conv_weights", -128, 127)
        conv_bias = check_int(data["conv_biases"], "conv_biases",
                              -(2**31), 2**31-1)
        dense = check_int(data["dense_weights"], "dense_weights", -128, 127)
        dense_bias = check_int(data["dense_biases"], "dense_biases",
                               -(2**31), 2**31-1)

    if conv.shape == (4, 1, 3, 3):
        conv = conv[:, 0, :, :]
    if conv.shape != (4, 3, 3) or conv_bias.shape != (4,):
        raise ValueError("Expected conv_weights (4,3,3)/(4,1,3,3), biases (4,)")

    if dense.shape == (10, 4, 13, 13):
        dense = dense.transpose(0, 2, 3, 1).reshape(10, FEATURES)
    elif dense.shape == (10, 13, 13, 4):
        dense = dense.reshape(10, FEATURES)
    elif dense.shape == (10, FEATURES):
        if args.dense_layout == "chw":
            dense = dense.reshape(10, 4, 13, 13).transpose(0, 2, 3, 1)
        dense = dense.reshape(10, FEATURES)
    else:
        raise ValueError("Expected dense_weights (10,676), (10,4,13,13) or (10,13,13,4)")

    if dense_bias.shape != (10,):
        raise ValueError("Expected dense_biases (10,)")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "cnn_weights_package.vhd").write_text(
        conv_package(conv, conv_bias), encoding="utf-8")
    (args.out_dir / "dense_weights_package.vhd").write_text(
        dense_package(dense, dense_bias), encoding="utf-8")
    print("Exported VHDL packages in", args.out_dir)
    print("WARNING: Verify activation scales, bias scales and score equivalence against the trained model.")


if __name__ == "__main__":
    main()
