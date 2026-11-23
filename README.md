# CNN Convolution Engine — VHDL / AXI4-Stream

A work-in-progress VHDL convolution block intended for a CNN processing pipeline on a Zynq-7000 FPGA SoC. **This repository is not presented as a complete, verified CNN.**

## Repository structure

- `rtl/cnn_conv.vhd`: convolution block with a default image size of 28 × 28, 8-bit AXI4-Stream input and 32-bit AXI4-Stream output packing four 8-bit activations.
- `rtl/conv_kernel.vhd`: weighted 3 × 3 convolution (nine multiply-accumulates and a bias term).
- `rtl/cnn_weights_package.vhd`: constants for four 3 × 3 filters and biases. **All checked-in values are currently zero placeholders**, not trained model parameters.
- `vivado/create_cnn_project.tcl`: script creating a standalone Vivado RTL project.

## Architecture

The convolution module instantiates four parallel `conv_kernel` units and uses two line buffers with a 3 × 3 sliding window. The source includes AXI4-Stream `TVALID`, `TREADY`, and `TLAST` handshaking, as well as scaling and activation logic. This code still requires functional verification.

## Build a minimal Vivado project

With AMD/Xilinx Vivado available, run from the repository root:

```bash
vivado -mode batch -source vivado/create_cnn_project.tcl
```

The script creates a minimal RTL project targeting `xc7z020clg484-1`. It **does not** reconstruct a complete PS/DMA SoC design, and does not run simulation or synthesis.

## Current limitations

- No standalone CNN testbench was identified in the original repository.
- The weights and biases in the checked-in package are all zero.
- Pooling, a classification head and complete end-to-end CNN inference are not established by the included files.
- No new simulation, implementation or on-board measurement was carried out during repository cleanup.

## Backup

The original full Vivado project is preserved in `backup-before-cleanup-2026-11-23`. The original configurable-convolution SoC block design belongs to the separate Sobel/convolution repository rather than this CNN-only source package. Generated files are excluded from the working branch, without modifying local files.
