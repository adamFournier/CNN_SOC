# CNN on FPGA — VHDL / AXI4-Stream

A compact CNN for **MNIST handwritten-digit classification (0–9)**, trained in PyTorch and implemented as a streaming RTL pipeline targeting a Zynq-7000 FPGA.

## Architecture

```text
28×28 grayscale image (8-bit)
          ↓
Conv2D 3×3, 4 filters + ReLU  →  26×26×4
          ↓
MaxPooling 2×2, stride 2     →  13×13×4
          ↓
Flatten                       →  676 features
          ↓
Dense 676 → 10               →  10 class scores (INT32)
```

The VHDL blocks communicate using **AXI4-Stream** (`TDATA`, `TVALID`, `TREADY`, `TLAST`). Four 8-bit convolution channels are packed into each 32-bit transfer. The Dense layer accumulates results for the ten classes and outputs ten scores per image.

## Project files

| File | Description |
| --- | --- |
| `Untitled0.ipynb` | PyTorch training, INT8 quantization and weight export |
| `rtl/cnn_conv.vhd` / `conv_kernel.vhd` | 3×3 convolution and ReLU |
| `rtl/maxpool2x2_axi.vhd` | Streaming 2×2 MaxPooling |
| `rtl/dense_layer_axi.vhd` | Fully connected layer, 676 → 10 |
| `rtl/cnn_top.vhd` | Connects the full CNN pipeline |
| `rtl/*weights_package.vhd` | Quantized weight and bias constants |
| `tools/export_weights.py` | Converts an INT8 NPZ into VHDL weight packages |
| `tb/` | VHDL simulation testbenches |

## How to run

**1. Train and export weights**

Open `Untitled0.ipynb` in Jupyter or Google Colab and run all cells. The last cell generates `tiny_cnn_weights_int8.npz`.

**2. Generate the VHDL weights**

Place the NPZ file in the repository root and run (requires NumPy):

```bash
python tools/export_weights.py tiny_cnn_weights_int8.npz
```

**3. Create the Vivado project**

Requires Vivado with support for `xc7z020clg484-1`.

```bash
vivado -mode batch -source vivado/create_cnn_project.tcl
```

The generated project is in `build/cnn_conv_project/`, with `cnn_top` as its top module.

**4. Run the simulations**

With Vivado:

```bash
vivado -mode batch -source vivado/run_tests.tcl
```

Or with GHDL and Make:

```bash
make test
```

The MaxPooling, Dense and CNN stream testbenches pass in GitHub Actions.

> **Note:** The notebook reports 95.53% FP32 and 95.51% simulated INT8 accuracy on MNIST. FPGA inference accuracy still requires matching the Python and VHDL quantization scales and validating the trained weights in hardware.
