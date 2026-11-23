# Streaming CNN on Zynq-7000 — Conv3x3 + ReLU + MaxPool2x2 + Dense10

A handwritten VHDL implementation of a compact inference pipeline designed for **28 × 28 grayscale images** and AXI4-Stream interfaces. The existing convolution/ReLU stage has been retained; a 2 × 2 max-pooling stage, a 10-class fully connected layer, a top-level integration module and self-checking testbenches have been added.

**Important:** The pipeline is structurally implemented, but it is **not a trained, validated Fashion-MNIST classifier yet**. The original convolution weights/biases are zero placeholders. The Dense package contains sparse **synthetic demonstration coefficients** for standalone arithmetic verification, NOT learned parameters. You must export compatible trained and quantized weights before claiming real inference accuracy.

## Architecture

```text
Grayscale image: 28 x 28 x 1, uint8
        |
        | AXI4-Stream 8-bit pixel data
        v
cnn_conv.vhd (existing): VALID Conv3x3, 4 filters, input quantization,
                         arithmetic right shift, ReLU/clamp [0,127]
        |
        | 26 x 26 x 4: 676 packed 32-bit beats
        v
maxpool2x2_axi.vhd: 2x2 per-channel maximum, stride 2
        |
        | 13 x 13 x 4: 169 packed 32-bit beats
        v
dense_layer_axi.vhd: 676 inputs -> 10 signed INT32 scores
        |
        | 10 AXI4-Stream beats, one signed score per class,
        | TLAST asserted on the tenth score
        v
Output / PS / DMA / classification postprocessing
```

Four 8-bit channels are packed as `[channel 3 | channel 2 | channel 1 | channel 0]`. Spatial positions are streamed in row-major order. Dense features are flattened **pixel-major**, with channels 0–3 adjacent. `TREADY/TVALID` provide flow control, and the end-of-frame condition is propagated as a new `TLAST` at each stage.

The MaxPool uses a buffer for the horizontal maxima of the preceding row. The Dense stage accumulates four INT8 multiplications per class per pooled input beat, with ten parallel INT32 accumulators; it then emits ten scores serially. While scores are emitted, the Dense input is backpressured.

## Repository layout

| Path | Purpose |
| --- | --- |
| `rtl/cnn_conv.vhd` | Existing convolution, scaling and ReLU stage (4 filters) |
| `rtl/conv_kernel.vhd` | Existing weighted 3×3 convolution kernel |
| `rtl/cnn_weights_package.vhd` | Existing zero-valued CONV weights/biases — replace after training |
| `rtl/maxpool2x2_axi.vhd` | New 2×2 stride-2 streaming MaxPool |
| `rtl/dense_layer_axi.vhd` | New 676→10 signed INT8 MAC / INT32 accumulator stage |
| `rtl/dense_weights_package.vhd` | Sparse synthetic Dense test weights — replace after training |
| `rtl/cnn_top.vhd` | Complete ready/valid RTL interconnection |
| `tb/` | Self-checking MaxPool and Dense tests plus top-level stream smoke test |
| `vivado/create_cnn_project.tcl` | Recreate minimal Vivado project |
| `vivado/run_tests.tcl` | Run the three VHDL testbenches in XSim |
| `tools/export_weights.py` | Export already-quantized NPZ values into VHDL packages |

## Recreate the Vivado project

Requires AMD/Xilinx Vivado with VHDL-2008 support; target is `xc7z020clg484-1`.

```bash
vivado -mode batch -source vivado/create_cnn_project.tcl
```

Creates `build/cnn_conv_project/` with `cnn_top` as synthesis top and `tb_cnn_top` as default simulation top.

To run all self-checking testbenches:

```bash
vivado -mode batch -source vivado/run_tests.tcl
```

- `tb_maxpool2x2`: two 4×4 frames, four-channel maximum values, backpressure and `TLAST`.
- `tb_dense_layer`: two short frames, signed MACs, demo-weight reference scores, backpressure and `TLAST`.
- `tb_cnn_top`: two 28×28 frames, 10 defined output scores per frame, framing and backpressure. This is a **stream integration smoke test**, not an accuracy benchmark.

The three RTL testbenches passed in GitHub Actions using **GHDL**. Vivado/XSim, synthesis, timing closure, resource usage, and hardware operation are still unverified.

## Exporting learned weights

Prepare an NPZ containing **already-quantized integer** arrays:
- `conv_weights`: signed INT8 shape `(4,1,3,3)` or `(4,3,3)`
- `conv_biases`: signed INT32 shape `(4,)`
- `dense_weights`: signed INT8 shape `(10,676)` (default PyTorch CHW flatten), `(10,4,13,13)` or `(10,13,13,4)`
- `dense_biases`: signed INT32 shape `(10,)`

```bash
python tools/export_weights.py my_quantized_weights.npz
```

The exporter places the weight packages in `rtl/`. It **does not** train or quantize a network. For correct results, verify the original convolution's `pixel >> 2` input quantization and `accumulator >> 8` output scaling against the training/quantization pipeline. The final 10 signed scores are unnormalized logits; softmax/argmax can be done on the CPU if required. A simple RTL bias/shift scheme is not automatically equivalent to per-channel PyTorch quantization.

## Remaining engineering verification

- Fill in genuinely trained, quantization-compatible convolution and Dense weights.
- Validate outputs numerically against a Python/PyTorch reference across representative images.
- Execute XSim tests, run synthesis and check DSP/LUT/FF/BRAM use and timing closure.
- Integrate `cnn_top` with the Zynq PS, AXI DMA, memory, software and appropriate transfer lengths.
- Check/extend overflow and quantization behavior for the trained model.

The previous full Vivado project remains preserved in `backup-before-cleanup-2026-11-23`, and `main` is unchanged until the Pull Request is merged.

## PyTorch training and INT8 export

The added `Untitled0.ipynb` trains the matching 1→4 Conv3x3 + ReLU + MaxPool2x2 + Dense10 model on **MNIST handwritten digits**. Its saved notebook output reports **95.53% FP32** and **95.51% simulated INT8** test accuracy. These are Python metrics, **not hardware-validated accuracy**.

After running the notebook from a fresh Python kernel, its final cell generates `tiny_cnn_weights_int8.npz` with the following arrays: `conv_weights`, `conv_biases`, `dense_weights`, `dense_biases`. Download the NPZ file to your local CNN_SOC clone, then generate the synthesizable packages:

```bash
python tools/export_weights.py tiny_cnn_weights_int8.npz
make test
```

The converter transposes PyTorch's channel-major `(10,676)` Dense flattening to the **pixel-major four-channel AXI stream** expected by the RTL. It also checks INT8/INT32 ranges.

**Important scaling caveat:** The existing `cnn_conv.vhd` uses integer input `pixel >> 2` and convolution output `accumulator >> 8`; the Python notebook computes power-of-two scales from calibration data. These must be checked and, if necessary, synchronized. Integer rounding on the CPU can also differ from shifts in RTL. Exporting coefficients alone does not guarantee bit-exact results or MNIST accuracy on hardware.

To test the converter without trained weights: `python tests/test_export_weights.py` (requires NumPy and GHDL).
