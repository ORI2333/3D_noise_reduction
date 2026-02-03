# ===================================
# 3D Noise Reduction Vivado Project Creation Script
# ===================================
# Author: ori_zh
# Date: 2026/02/03
# Description: 自动创建和配置 Vivado 项目
# ===================================

# 项目配置
set project_name "3DNR"
set project_dir [file normalize .]

# 创建项目（如果存在则覆盖）
create_project $project_name $project_dir -force
puts "INFO: Created project: $project_name"

# 设置器件（根据实际器件修改）
# 常见型号:
# - Artix-7: xc7a200tfbg484-2
# - Kintex-7: xc7k325tffg676-2
# - Zynq-7000: xc7z020clg400-2
set_property part xc7a200tfbg484-2 [current_project]
puts "INFO: Set target device to: xc7a200tfbg484-2"

# 设置项目属性
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# ===================================
# 添加 RTL 源文件
# ===================================
puts "INFO: Adding RTL source files..."

# 获取所有 .sv 文件
set rtl_files [glob -nocomplain ../rtl/*.sv]
if {[llength $rtl_files] > 0} {
    add_files -fileset sources_1 $rtl_files
    puts "INFO: Added [llength $rtl_files] SystemVerilog files"
} else {
    puts "WARNING: No SystemVerilog files found in ../rtl/"
}

# 如果有 Verilog 文件
set v_files [glob -nocomplain ../rtl/*.v]
if {[llength $v_files] > 0} {
    add_files -fileset sources_1 $v_files
    puts "INFO: Added [llength $v_files] Verilog files"
}

# 如果有 VHDL 文件
set vhd_files [glob -nocomplain ../rtl/*.vhd]
if {[llength $vhd_files] > 0} {
    add_files -fileset sources_1 $vhd_files
    puts "INFO: Added [llength $vhd_files] VHDL files"
}

# ===================================
# 添加约束文件
# ===================================
puts "INFO: Adding constraint files..."

# UCF 约束文件（ISE 格式）
set ucf_files [glob -nocomplain ../pin/*.ucf]
if {[llength $ucf_files] > 0} {
    add_files -fileset constrs_1 $ucf_files
    puts "INFO: Added [llength $ucf_files] UCF constraint files"
}

# XDC 约束文件（Vivado 格式）
set xdc_files [glob -nocomplain ../pin/*.xdc]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
    puts "INFO: Added [llength $xdc_files] XDC constraint files"
}

# ===================================
# 添加 IP 核
# ===================================
puts "INFO: Adding IP cores..."

# 查找所有 .xci IP 配置文件
set ip_files [glob -nocomplain 3DNR.srcs/sources_1/ip/*/*.xci]
if {[llength $ip_files] > 0} {
    foreach ip_file $ip_files {
        add_files -fileset sources_1 $ip_file
    }
    puts "INFO: Added [llength $ip_files] IP cores"
    
    # 生成 IP 核输出产品
    puts "INFO: Generating IP output products (this may take a few minutes)..."
    upgrade_ip [get_ips]
    generate_target all [get_ips]
} else {
    puts "WARNING: No IP cores found in 3DNR.srcs/sources_1/ip/"
}

# ===================================
# 设置顶层模块
# ===================================
# 综合顶层（根据实际修改）
# set_property top DDD_Noise_8CH [current_fileset]

# 仿真顶层
set_property top tb_Sys [current_fileset -simset]
set_property top_lib xil_defaultlib [current_fileset -simset]

puts "INFO: Set simulation top module to: tb_Sys"

# ===================================
# 配置仿真设置
# ===================================
set_property -name {xsim.simulate.runtime} -value {1000us} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true} -objects [get_filesets sim_1]

# ===================================
# 刷新项目
# ===================================
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "========================================="
puts "INFO: Project creation completed successfully!"
puts "========================================="
puts "Next steps:"
puts "  1. Open Vivado: vivado 3DNR.xpr"
puts "  2. Review RTL files in 'Sources' panel"
puts "  3. Run simulation or synthesis"
puts "========================================="
