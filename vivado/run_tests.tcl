# Create the project, then run independent testbenches in Vivado/XSim.
# vivado -mode batch -source vivado/run_tests.tcl
set here [file dirname [file normalize [info script]]]
source [file join $here create_cnn_project.tcl]

foreach test_name {tb_maxpool2x2 tb_dense_layer tb_cnn_top} {
    puts "Running $test_name"
    set_property top $test_name [get_filesets sim_1]
    update_compile_order -fileset sim_1
    launch_simulation -simset sim_1 -mode behavioral
    run all
    close_sim
}
puts "All three testbenches launched. Inspect simulator output for PASS/FAIL."
