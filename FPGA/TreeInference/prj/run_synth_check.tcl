open_project "F:/EngineeringWarehouse/NR/3D_noise_reduction/FPGA/TreeInference/prj/TreeInference.xpr"
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
set st [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$st"
if {[string first "Complete" $st] < 0} {
  puts "SYNTH_FAILED_STATUS=$st"
  exit 1
}
open_run synth_1
report_utilization -file "F:/EngineeringWarehouse/NR/3D_noise_reduction/FPGA/TreeInference/prj/synth_1_utilization.rpt"
report_timing_summary -file "F:/EngineeringWarehouse/NR/3D_noise_reduction/FPGA/TreeInference/prj/synth_1_timing.rpt"
close_project
exit 0
