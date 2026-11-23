# Run from repository root
create_project cnn_conv_project ./build/cnn_conv_project -part xc7z020clg484-1 -force
add_files -norecurse ./rtl/cnn_weights_package.vhd
add_files -norecurse ./rtl/conv_kernel.vhd
add_files -norecurse ./rtl/cnn_conv.vhd
set_property file_type {VHDL 2008} [get_files ./rtl/cnn_weights_package.vhd]
set_property file_type {VHDL 2008} [get_files ./rtl/conv_kernel.vhd]
set_property file_type {VHDL 2008} [get_files ./rtl/cnn_conv.vhd]
set_property top cnn_conv [get_filesets sources_1]
update_compile_order -fileset sources_1
puts "CNN RTL standalone project created. No simulation or synthesis has been run."
