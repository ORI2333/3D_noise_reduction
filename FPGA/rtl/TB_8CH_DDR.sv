`timescale 1ns / 1ps
//****************************************Copyright (c)***********************************// 
// Copyright(C)            ORI2333, 2026-2027
// All rights reserved      
// File name:               
// Last modified Date:     2026/02/02 13:55:50 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             ori_zh
// Created date:           2026/02/02 13:55:50 
// Version:                V1.0 
// TEXT NAME:              TB_8CH_DDR.sv 
// PATH:                   F:\EngineeringWarehouse\NR\3D_noise_reduction\FPGA\rtl\TB_8CH_DDR.sv 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************//                                               
module tb_Sys;

    parameter          H_DISP           = 640                            ;
    parameter          V_DISP           = 480                            ;
    parameter          CMOS_H_PIXEL     = 800                            ;
    parameter          CMOS_V_PIXEL     = 600                            ;

    // signals define for DDR3
    wire                 [      31: 0]     ddr3_dq                          ;
    wire                 [      13: 0]     ddr3_addr                        ;//Address
    wire                 [       2: 0]     ddr3_ba                          ;//Bank Address
    wire                 [       3: 0]     ddr3_dqs_p                       ;
    wire                 [       3: 0]     ddr3_dqs_n                       ;
    wire                 [       0: 0]     ddr3_ck_p                        ;
    wire                 [       0: 0]     ddr3_ck_n                        ;
    wire                 [       3: 0]     ddr3_dm                          ;//Input Data Mask
    wire                 [       0: 0]     ddr3_cke                         ;//Clock Enable
    wire                 [       0: 0]     ddr3_cs_n                        ;//Chip Select
    wire                                   ddr3_ras_n                       ;//Row Address Enable
    wire                                   ddr3_cas_n                       ;//Column Address Enable
    wire                                   ddr3_we_n                        ;//Write Enable
    wire                 [       0: 0]     ddr3_odt                         ;//On-die termination enable
    wire                                   ddr3_reset_n                     ;
    
    reg                                    aresetn                          ;

    // System signals
    reg                                    rst                              ;
    reg                                    sys_rst                          ;
    reg                                    clk                              ;
    reg                                    ref_clk                          ;
    reg                                    sys_clk                          ;

    // image data signals
    reg                  [       7: 0]     i_data_R[7:0]                    ;// 8bit 
    reg                  [       7: 0]     i_data_G[7:0]                    ;// 8bit 
    reg                  [       7: 0]     i_data_B[7:0]                    ;// 8bit 
    reg                                    i_fval                           ;
    reg                                    i_lval                           ;

    // output image data signals
    wire                 [       7: 0]     o_data_R[7:0]                    ;
    wire                 [       7: 0]     o_data_G[7:0]                    ;
    wire                 [       7: 0]     o_data_B[7:0]                    ;
    wire                                   o_fval                           ;
    wire                                   o_lval                           ;

    // DDR Controller status signals
    wire                                   init_calib_complete              ;
    wire                                   ui_clk                           ;
    wire                                   ui_clk_sync_rst                  ;
    wire                                   mmcm_locked                      ;
    wire                                   app_sr_active                    ;
    wire                                   app_ref_ack                      ;
    wire                                   app_zq_ack                       ;
    wire                 [       3: 0]     s_axi_bid                        ;
    wire                 [       3: 0]     s_axi_rid                        ;

    // AXI DDR Interface signals (DUT and DDR)
    wire                 [      31: 0]     M_AXI_AWADDR                     ;
    wire                                   M_AXI_AWVALID                    ;
    wire                                   M_AXI_AWREADY                    ;
    wire                 [       2: 0]     M_AXI_AWPROT                     ;
    wire                 [       1: 0]     M_AXI_AWLOCK                     ;
    wire                 [       3: 0]     M_AXI_AWCACHE                    ;
    wire                 [       2: 0]     M_AXI_AWSIZE                     ;
    wire                 [       1: 0]     M_AXI_AWBURST                    ;
    wire                 [       7: 0]     M_AXI_AWLEN                      ;
    wire                 [     255: 0]     M_AXI_WDATA                      ;
    wire                 [       7: 0]     M_AXI_WSTRB                      ;
    wire                                   M_AXI_WVALID                     ;
    wire                                   M_AXI_WREADY                     ;
    wire                                   M_AXI_WLAST                      ;
    wire                 [       1: 0]     M_AXI_BRESP                      ;
    wire                                   M_AXI_BVALID                     ;
    wire                                   M_AXI_BREADY                     ;
    wire                 [      31: 0]     M_AXI_ARADDR                     ;
    wire                                   M_AXI_ARVALID                    ;
    wire                                   M_AXI_ARREADY                    ;
    wire                 [       2: 0]     M_AXI_ARPROT                     ;
    wire                 [       1: 0]     M_AXI_ARLOCK                     ;
    wire                 [       3: 0]     M_AXI_ARCACHE                    ;
    wire                 [       2: 0]     M_AXI_ARSIZE                     ;
    wire                 [       1: 0]     M_AXI_ARBURST                    ;
    wire                 [       7: 0]     M_AXI_ARLEN                      ;
    wire                 [     255: 0]     M_AXI_RDATA                      ;
    wire                 [       1: 0]     M_AXI_RRESP                      ;
    wire                                   M_AXI_RVALID                     ;
    wire                                   M_AXI_RREADY                     ;
    wire                                   M_AXI_RLAST                      ;

    // simulation signals 
    integer                                file_handle                      ;
    integer                                read_count                       ;
    integer                                pixel_x                          ;
    integer                                pixel_y                          ;
    integer                                mem_index                        ;
    integer                                test1_file                       ;
    integer                                test_a                           ;
    integer                                frame                            ;
    integer                                row                              ;
    integer                                col                              ;

    string                                 img_in_path                      ;
    string                                 img_out_path                     ;
    integer                                plusarg_ok                       ;
    integer                                skip_calib_wait                  ;

    // image memory
    reg                  [       7: 0]     image_mem[0:H_DISP * V_DISP*3 - 1]  ;// 640x480=307200
    reg                  [       7: 0]     out_mem  [0:H_DISP * V_DISP*3 - 1]  ;// 640x480=307200

    // results output file
    integer                                file                             ;
    reg                  [      31: 0]     out_counter                      ;

// Clock generation
// 100MHz 
initial begin
    clk = 0;
    forever #5 clk = ~clk;                                      
end
// 200MHz 
initial begin
    ref_clk = 0;
    forever #2.5 ref_clk = ~ref_clk;  
end
// 400MHz                          
initial begin
    sys_clk = 0;
    forever #1.25 sys_clk = ~sys_clk;                           
end

// reset generation
initial begin
    sys_rst = 0;
    # 10_000;
    sys_rst = 1;
end

// Get directory name from a given path
function automatic string _dirname(input string p);
    int i;
    for (i = p.len() - 1; i >= 0; i--) begin
        byte c;
        c = p.getc(i);
        if ((c == 47) || (c == 92)) begin // '/' or '\'
            return p.substr(0, i);
        end
    end
    return ".";
endfunction

// -------------------------------------------------------------------------------------
// Test procedure
// -------------------------------------------------------------------------------------
initial begin
    $display("Loading image data...");

    if (img_in_path == "") begin
        string tb_dir;
        tb_dir = _dirname(`__FILE__);
        img_in_path = {tb_dir, "/../../script/image_py/out/Bmp_2_rgb888.txt"};
        img_out_path = {tb_dir, "/../../script/image_py/out/rgb888_output.txt"};
        plusarg_ok = $value$plusargs("IMG_IN=%s", img_in_path);
        plusarg_ok = $value$plusargs("IMG_OUT=%s", img_out_path);
    end

    $display("IMG_IN  = %s", img_in_path);
    $display("IMG_OUT = %s", img_out_path);
    // read image data from file to image_mem
    test1_file = $fopen(img_in_path, "r");
    if (!test1_file) begin
        $display("ERROR: cannot open IMG_IN file: %s", img_in_path);
        $finish;
    end
    $fclose(test1_file);
    $readmemh(img_in_path, image_mem);
    // print first 16 pixels for verification
    $display("image_mem[0..15] = %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h",
                image_mem[0], image_mem[1], image_mem[2], image_mem[3],
                image_mem[4], image_mem[5], image_mem[6], image_mem[7],
                image_mem[8], image_mem[9], image_mem[10], image_mem[11],
                image_mem[12], image_mem[13], image_mem[14], image_mem[15]);
    $display("Image loading complete");

    // initialize signals
    rst = 'b1;

    for(int k=0; k<8; k++) begin
            i_data_R[k] = 8'b0; 
            i_data_G[k] = 8'b0; 
            i_data_B[k] = 8'b0;
        end

    i_fval = 0;
    i_lval = 0;

    #2000;
    rst = 0;

    // Monitor DDR initialization
    $display("[%t] Waiting for DDR3 calibration...", $time);
    fork
        begin
            wait (init_calib_complete);
            $display("[%t] DDR3 calibration complete!", $time);
        end
        begin
            #100_000_000; // 100ms timeout
            if (!init_calib_complete) begin
                $display("[%t] ERROR: DDR3 calibration timeout!", $time);
                $display("[%t] init_calib_complete = %b", $time, init_calib_complete);
                $display("[%t] mmcm_locked = %b", $time, mmcm_locked);
                $display("[%t] ui_clk_sync_rst = %b", $time, ui_clk_sync_rst);
                $finish;
            end
        end
    join_any
    disable fork;

    // start frame transmission
    for (frame = 0; frame < 2; frame = frame + 1) begin
        i_fval = 1; // frame valid
        for (row = 0; row < CMOS_V_PIXEL; row = row + 1) begin
            // line valid
            for (col = 0; col < (CMOS_H_PIXEL * 3); col = col + 24) begin
                // only send data within active area
                if (col >= ((CMOS_H_PIXEL - H_DISP) * 3) && col < ((CMOS_H_PIXEL - H_DISP) * 3 + (H_DISP * 3)) &&
                    row >= ((CMOS_V_PIXEL - V_DISP)/2) && row < (((CMOS_V_PIXEL - V_DISP)/2) + V_DISP)) begin
                    // calculate pixel index
                    pixel_x     =  col - ((CMOS_H_PIXEL - H_DISP) * 3);
                    pixel_y     =  row - ((CMOS_V_PIXEL - V_DISP)/2);
                    mem_index   =  (pixel_y * H_DISP * 3) + pixel_x ;
                    i_lval      =  1                                ;        

                    // load 8 pixels (24 bytes) of data
                    for (int k=0; k<8; k++) begin
                        i_data_R[k] = image_mem[mem_index + 3*k + 0];
                        i_data_G[k] = image_mem[mem_index + 3*k + 1];
                        i_data_B[k] = image_mem[mem_index + 3*k + 2];
                    end

                end 
                else begin
                    i_lval = 0;
                end
                #10;
            end
            i_lval = 0;
            #40; 
        end
        i_fval = 0;
        #1000; 
    end
    $display("Testbench finished.");
end

// Output image data to file
initial begin
    
    if (img_out_path == "") begin
        string tb_dir;
        tb_dir = _dirname(`__FILE__);
        img_in_path = {tb_dir, "/../../script/image_py/out/Bmp_2_rgb888.txt"};
        img_out_path = {tb_dir, "/../../script/image_py/out/rgb888_output.txt"};
        plusarg_ok = $value$plusargs("IMG_IN=%s", img_in_path);
        plusarg_ok = $value$plusargs("IMG_OUT=%s", img_out_path);
    end
    file = $fopen(img_out_path, "w");
    if (!file) begin
        $display("Error opening file!");
        $finish;
    end

end

// output data capture
always @(posedge clk)begin
    if(rst)begin
        out_counter <= 'b0;
    end
    else begin
        if(u_DDD_Noise_8CH.u_U6_Algorithm_Subsys.o_d_val) begin
            out_counter <= out_counter + 24;
        end
        else if(u_DDD_Noise_8CH.o_frame_finish_pulse)begin
            out_counter <= 'b0          ;
        end
        else begin
            out_counter <= out_counter;
        end
    end
end

// store output data to out_mem
always @(posedge clk ) begin
    if (u_DDD_Noise_8CH.u_U6_Algorithm_Subsys.o_d_val) begin
        for (int k=0; k<8; k++) begin
        out_mem[out_counter + 3*k + 0] <= o_data_R[k];
        out_mem[out_counter + 3*k + 1] <= o_data_G[k];
        out_mem[out_counter + 3*k + 2] <= o_data_B[k];
        end
    end
end

// write output data to file when frame is finished
integer a;
initial begin
    forever begin
    @(posedge clk);
        if (u_DDD_Noise_8CH.o_frame_finish_pulse) begin

            for (a = 0; a < H_DISP * V_DISP * 3; a = a + 1) begin
                $fdisplay(file,"%h",out_mem[a][7:0]);
            end
            $display("Write_Over!!");
                            
            #1000;          
            $fclose(file);
            $finish;
        end 
    end
end

// DDR controller AXI reset 
always @(posedge ui_clk) begin
    aresetn	<= ~ui_clk_sync_rst;
end

// Monitor DDR status signals
initial begin
    forever begin
        @(posedge init_calib_complete);
        $display("[%t] DDR3 init_calib_complete asserted", $time);
    end
end

initial begin
    forever begin
        @(posedge mmcm_locked);
        $display("[%t] DDR3 mmcm_locked asserted", $time);
    end
end
    

// -------------------------------------------------------------------------------------
// Instantiate modules
// -------------------------------------------------------------------------------------
    // Device Under Test (DUT)
    DDD_Noise_8CH#(
        .DDR_BASE_ADDR                     (0                              ),
        .WAIT                              (0                              ),
        .CMOS_H_PIXEL                      (CMOS_H_PIXEL                   ),
        .CMOS_V_PIXEL                      (CMOS_V_PIXEL                   ),
        .H_DISP                            (H_DISP                         ),
        .V_DISP                            (V_DISP                         ),
        .MACROBLOCK_THREASHOLD             (32                             ) 
    ) u_DDD_Noise_8CH(
        // System
        .clk                                       (clk                        ),
        .ui_clk                                    (ui_clk                     ),
        .rst_n                                     (~(rst)                     ),
        .ui_clk_sync_rst                           (ui_clk_sync_rst            ),
        // Data_in
        .i_data_R                                  (i_data_R                   ),
        .i_data_G                                  (i_data_G                   ),
        .i_data_B                                  (i_data_B                   ),
        .i_fval                                    (i_fval                     ),
        .i_lval                                    (i_lval                     ),
        // Data_out:TFT_LCD
        .o_fval                                    (o_fval                     ),
        .o_lval                                    (o_lval                     ),
        .o_data_R                                  (o_data_R                   ),
        .o_data_G                                  (o_data_G                   ),
        .o_data_B                                  (o_data_B                   ),
        // DDR_Inteface
        // AXI Full Interface DDR Port Signals (64-bit)
        .M_AXI_AWADDR                              (M_AXI_AWADDR               ),// Write address
        .M_AXI_AWVALID                             (M_AXI_AWVALID              ),// Write address valid
        .M_AXI_AWREADY                             (M_AXI_AWREADY              ),// Write address ready
        .M_AXI_AWPROT                              (M_AXI_AWPROT               ),// Write address protection type
        .M_AXI_AWLOCK                              (M_AXI_AWLOCK               ),// Write address lock type
        .M_AXI_AWCACHE                             (M_AXI_AWCACHE              ),// Write address cache type
        .M_AXI_AWSIZE                              (M_AXI_AWSIZE               ),// Write address burst size
        .M_AXI_AWBURST                             (M_AXI_AWBURST              ),// Write address burst type
        .M_AXI_AWLEN                               (M_AXI_AWLEN                ),// Write address burst length
        .M_AXI_WDATA                               (M_AXI_WDATA                ),// Write data
        .M_AXI_WSTRB                               (M_AXI_WSTRB                ),// Write strobes (byte enables)
        .M_AXI_WVALID                              (M_AXI_WVALID               ),// Write data valid
        .M_AXI_WREADY                              (M_AXI_WREADY               ),// Write data ready
        .M_AXI_WLAST                               (M_AXI_WLAST                ),// Write last
        .M_AXI_BRESP                               (M_AXI_BRESP                ),// Write response
        .M_AXI_BVALID                              (M_AXI_BVALID               ),// Write response valid
        .M_AXI_BREADY                              (M_AXI_BREADY               ),// Write response ready
        .M_AXI_ARADDR                              (M_AXI_ARADDR               ),// Read address
        .M_AXI_ARVALID                             (M_AXI_ARVALID              ),// Read address valid
        .M_AXI_ARREADY                             (M_AXI_ARREADY              ),// Read address ready
        .M_AXI_ARPROT                              (M_AXI_ARPROT               ),// Read address protection type
        .M_AXI_ARLOCK                              (M_AXI_ARLOCK               ),// Read address lock type
        .M_AXI_ARCACHE                             (M_AXI_ARCACHE              ),// Read address cache type
        .M_AXI_ARSIZE                              (M_AXI_ARSIZE               ),// Read address burst size
        .M_AXI_ARBURST                             (M_AXI_ARBURST              ),// Read address burst type
        .M_AXI_ARLEN                               (M_AXI_ARLEN                ),// Read address burst length
        .M_AXI_RDATA                               (M_AXI_RDATA                ),// Read data
        .M_AXI_RRESP                               (M_AXI_RRESP                ),// Read response
        .M_AXI_RVALID                              (M_AXI_RVALID               ),// Read data valid
        .M_AXI_RREADY                              (M_AXI_RREADY               ),// Read data ready
        .M_AXI_RLAST                               (M_AXI_RLAST                ) // Read last
    );

    // DDR3 Controller Instance（ AXI transfer to DDR3 PHY）
    DDR_Controller u_DDR_Controller (
        // Memory interface ports
        .ddr3_addr                                 (ddr3_addr                  ),// output [13:0]		ddr3_addr
        .ddr3_ba                                   (ddr3_ba                    ),// output [2:0]		ddr3_ba
        .ddr3_cas_n                                (ddr3_cas_n                 ),// output			ddr3_cas_n
        .ddr3_ck_n                                 (ddr3_ck_n                  ),// output [0:0]		ddr3_ck_n
        .ddr3_ck_p                                 (ddr3_ck_p                  ),// output [0:0]		ddr3_ck_p
        .ddr3_cke                                  (ddr3_cke                   ),// output [0:0]		ddr3_cke
        .ddr3_ras_n                                (ddr3_ras_n                 ),// output			ddr3_ras_n
        .ddr3_reset_n                              (ddr3_reset_n               ),// output			ddr3_reset_n
        .ddr3_we_n                                 (ddr3_we_n                  ),// output			ddr3_we_n
        .ddr3_dq                                   (ddr3_dq                    ),// inout [31:0]		ddr3_dq
        .ddr3_dqs_n                                (ddr3_dqs_n                 ),// inout [3:0]		ddr3_dqs_n
        .ddr3_dqs_p                                (ddr3_dqs_p                 ),// inout [3:0]		ddr3_dqs_p
        .ddr3_cs_n                                 (ddr3_cs_n                  ),// output [0:0]		ddr3_cs_n
        .ddr3_dm                                   (ddr3_dm                    ),// output [3:0]		ddr3_dm
        .ddr3_odt                                  (ddr3_odt                   ),// output [0:0]		ddr3_odt
        // DDR control ports
        .app_sr_req                                (1'b0                       ),// input			app_sr_req
        .app_ref_req                               (1'b0                       ),// input			app_ref_req
        .app_zq_req                                (1'b0                       ),// input			app_zq_req
        .app_sr_active                             (app_sr_active              ),// output			app_sr_active
        .app_ref_ack                               (app_ref_ack                ),// output			app_ref_ack
        .app_zq_ack                                (app_zq_ack                 ),// output			app_zq_ack
        // Application interface ports
        .init_calib_complete                       (init_calib_complete        ),// output			init_calib_complete
        .ui_clk                                    (ui_clk                     ),// output			ui_clk
        .ui_clk_sync_rst                           (ui_clk_sync_rst            ),// output			ui_clk_sync_rst
        .mmcm_locked                               (mmcm_locked                ),// output			mmcm_locked
        .aresetn                                   (aresetn                    ),// input			aresetn
        // write channel
            // Slave Interface Write Address Ports
        .s_axi_awid                                (4'b0                       ),// input [3:0]			s_axi_awid
        .s_axi_awaddr                              (M_AXI_AWADDR[28:0]         ),// input [28:0]			s_axi_awaddr
        .s_axi_awlen                               (M_AXI_AWLEN                ),// input [7:0]			s_axi_awlen
        .s_axi_awsize                              (M_AXI_AWSIZE               ),// input [2:0]			s_axi_awsize
        .s_axi_awburst                             (M_AXI_AWBURST              ),// input [1:0]			s_axi_awburst
        .s_axi_awlock                              (M_AXI_AWLOCK[0]            ),// input [0:0]			s_axi_awlock
        .s_axi_awcache                             (M_AXI_AWCACHE              ),// input [3:0]			s_axi_awcache
        .s_axi_awprot                              (M_AXI_AWPROT               ),// input [2:0]			s_axi_awprot
        .s_axi_awqos                               (4'b0                       ),// input [3:0]			s_axi_awqos
        .s_axi_awvalid                             (M_AXI_AWVALID              ),// input			s_axi_awvalid
        .s_axi_awready                             (M_AXI_AWREADY              ),// output			s_axi_awready
            // Slave Interface Write Data Ports
        .s_axi_wdata                               (M_AXI_WDATA                ),// input [255:0]			s_axi_wdata
        .s_axi_wstrb                               (M_AXI_WSTRB                ),// input [31:0]			s_axi_wstrb
        .s_axi_wlast                               (M_AXI_WLAST                ),// input			s_axi_wlast
        .s_axi_wvalid                              (M_AXI_WVALID               ),// input			s_axi_wvalid
        .s_axi_wready                              (M_AXI_WREADY               ),// output			s_axi_wready
            // Slave Interface Write Response Ports
        .s_axi_bid                                 (s_axi_bid                  ),// output [3:0]			s_axi_bid
        .s_axi_bresp                               (M_AXI_BRESP                ),// output [1:0]			s_axi_bresp
        .s_axi_bvalid                              (M_AXI_BVALID               ),// output			s_axi_bvalid
        .s_axi_bready                              (M_AXI_BREADY               ),// input			s_axi_bready
        // read channel
            // Slave Interface Read Address Ports
        .s_axi_arid                                (4'b0                       ),// input [3:0]			s_axi_arid
        .s_axi_araddr                              (M_AXI_ARADDR[31:0]         ),// input [28:0]			s_axi_araddr
        .s_axi_arlen                               (M_AXI_ARLEN                ),// input [7:0]			s_axi_arlen
        .s_axi_arsize                              (M_AXI_ARSIZE               ),// input [2:0]			s_axi_arsize
        .s_axi_arburst                             (M_AXI_ARBURST              ),// input [1:0]			s_axi_arburst
        .s_axi_arlock                              (M_AXI_ARLOCK[0]            ),// input [0:0]			s_axi_arlock
        .s_axi_arcache                             (M_AXI_ARCACHE              ),// input [3:0]			s_axi_arcache
        .s_axi_arprot                              (M_AXI_ARPROT               ),// input [2:0]			s_axi_arprot
        .s_axi_arqos                               (4'b0                       ),// input [3:0]			s_axi_arqos
        .s_axi_arvalid                             (M_AXI_ARVALID              ),// input			s_axi_arvalid
        .s_axi_arready                             (M_AXI_ARREADY              ),// output			s_axi_arready
            // Slave Interface Read Data Ports
        .s_axi_rid                                 (s_axi_rid                  ),// output [3:0]			s_axi_rid
        .s_axi_rdata                               (M_AXI_RDATA                ),// output [255:0]			s_axi_rdata
        .s_axi_rresp                               (M_AXI_RRESP                ),// output [1:0]			s_axi_rresp
        .s_axi_rlast                               (M_AXI_RLAST                ),// output			s_axi_rlast
        .s_axi_rvalid                              (M_AXI_RVALID               ),// output			s_axi_rvalid
        .s_axi_rready                              (M_AXI_RREADY               ),// input			s_axi_rready
        // System Clock Ports
        .sys_clk_i                                 (sys_clk                    ),
        // Reference Clock Ports
        .clk_ref_i                                 (ref_clk                    ),
        .sys_rst                                   (sys_rst                    ) // input sys_rst
    );

    // simulated DDR3 memory model
    ddr3_model u_ddr3_model0(
        .rst_n                             (ddr3_reset_n                   ),
        .ck                                (ddr3_ck_p                      ),
        .ck_n                              (ddr3_ck_n                      ),
        .cke                               (ddr3_cke                       ),
        .cs_n                              (ddr3_cs_n                      ),
        .ras_n                             (ddr3_ras_n                     ),
        .cas_n                             (ddr3_cas_n                     ),
        .we_n                              (ddr3_we_n                      ),
        .dm_tdqs                           (ddr3_dm[1:0]                   ),
        .ba                                (ddr3_ba                        ),
        .addr                              (ddr3_addr                      ),
        .dq                                (ddr3_dq[15:0]                  ),
        .dqs                               (ddr3_dqs_p[1:0]                ),
        .dqs_n                             (ddr3_dqs_n[1:0]                ),
        .tdqs_n                            (                               ),
        .odt                               (ddr3_odt                       ) 
    );
        
    ddr3_model u_ddr3_model1(
        .rst_n                             (ddr3_reset_n                   ),
        .ck                                (ddr3_ck_p                      ),
        .ck_n                              (ddr3_ck_n                      ),
        .cke                               (ddr3_cke                       ),
        .cs_n                              (ddr3_cs_n                      ),
        .ras_n                             (ddr3_ras_n                     ),
        .cas_n                             (ddr3_cas_n                     ),
        .we_n                              (ddr3_we_n                      ),
        .dm_tdqs                           (ddr3_dm[3:2]                   ),
        .ba                                (ddr3_ba                        ),
        .addr                              (ddr3_addr                      ),
        .dq                                (ddr3_dq[31:16]                 ),
        .dqs                               (ddr3_dqs_p[3:2]                ),
        .dqs_n                             (ddr3_dqs_n[3:2]                ),
        .tdqs_n                            (                               ),
        .odt                               (ddr3_odt                       ) 
    );


endmodule
