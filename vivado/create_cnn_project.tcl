# Reproducible Vivado project for Conv3x3 + ReLU + MaxPool2x2 + Dense10.
# Run from any directory:
# vivado -mode batch -source vivado/create_cnn_project.tcl
set here [file dirname [file normalize [info script]]]
set root [file dirname $here]
set project_dir [file join $root build cnn_conv_project]
create_project cnn_conv_project $project_dir -part xc7z020clg484-1 -force

foreach source {
    cnn_weights_package.vhd
    dense_weights_package.vhd
    conv_kernel.vhd
    cnn_conv.vhd
    maxpool2x2_axi.vhd
    dense_layer_axi.vhd
    cnn_top.vhd
} {
    set file [file join $root rtl $source]
    add_files -norecurse $file
    set_property file_type {VHDL 2008} [get_files $file]
}

foreach testbench {
    tb_maxpool2x2.vhd
    tb_dense_layer.vhd
    tb_cnn_top.vhd
} {
    set file [file join $root tb $testbench]
    add_files -fileset sim_1 -norecurse $file
    set_property file_type {VHDL 2008} [get_files $file]
}
set_property top cnn_top [get_filesets sources_1]
set_property top tb_cnn_top [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Vivado project created at $project_dir. Default testbench: tb_cnn_top."
