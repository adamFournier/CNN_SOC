GHDL ?= ghdl
FLAGS := --std=08
WORKDIR := build/ghdl

RTL_SOURCES := \
  rtl/cnn_weights_package.vhd \
  rtl/dense_weights_package.vhd \
  rtl/conv_kernel.vhd \
  rtl/cnn_conv.vhd \
  rtl/maxpool2x2_axi.vhd \
  rtl/dense_layer_axi.vhd \
  rtl/cnn_top.vhd

TESTBENCHES := tb_maxpool2x2 tb_dense_layer tb_cnn_top

.PHONY: test clean
test:
	mkdir -p $(WORKDIR)
	$(GHDL) -a $(FLAGS) --workdir=$(WORKDIR) $(RTL_SOURCES) \
	  tb/tb_maxpool2x2.vhd tb/tb_dense_layer.vhd tb/tb_cnn_top.vhd
	@set -e; for tb in $(TESTBENCHES); do \
	  $(GHDL) -e $(FLAGS) --workdir=$(WORKDIR) $$tb; \
	  $(GHDL) -r $(FLAGS) --workdir=$(WORKDIR) $$tb --assert-level=error; \
	done

clean:
	rm -rf $(WORKDIR)
