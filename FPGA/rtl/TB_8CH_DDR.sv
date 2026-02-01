`timescale 1ns / 1ps
//    import axi_vip_pkg::*;
//    import DDR_VIP_pkg::*;


module tb_Sys;

parameter                           H_DISP                     =  640  ;
parameter                           V_DISP                     =  480  ;
parameter                           CMOS_H_PIXEL               =  800  ;
parameter                           CMOS_V_PIXEL               =  600  ;


    wire                      [  31: 0]         ddr3_dq                     ;

    wire                      [  13: 0]         ddr3_addr                   ;//Address
    wire                      [   2: 0]         ddr3_ba                     ;//Bank Address

    wire                      [   3: 0]         ddr3_dqs_p                  ;
    wire                      [   3: 0]         ddr3_dqs_n                  ;
//Output with read data. Edge-aligned with read data.
//Input with write data. Center-aligned to write data.

    wire                      [   0: 0]         ddr3_ck_p                   ;
    wire                      [   0: 0]         ddr3_ck_n                   ;
//differential clock inputs. All control and address input signals are sampled 
//on the crossing of the positive edge of CK and the negative edge of CK#

    wire                      [   3: 0]         ddr3_dm                     ;//Input Data Mask
    wire                      [   0: 0]         ddr3_cke                    ;//Clock Enable
    wire                      [   0: 0]         ddr3_cs_n                   ;//Chip Select
    wire                                        ddr3_ras_n                  ;//Row Address Enable
    wire                                        ddr3_cas_n                  ;//Column Address Enable
    wire                                        ddr3_we_n                   ;//Write Enable
    wire                      [   0: 0]         ddr3_odt                    ;//On-die termination enable
    wire                                        ddr3_reset_n                ;
  
    reg                                         rst                         ;
    reg                                         clk                         ;
    reg                       [   7: 0]         i_data_R   [7:0]            ;// 8bit 
    reg                       [   7: 0]         i_data_G   [7:0]            ;// 8bit 
    reg                       [   7: 0]         i_data_B   [7:0]            ;// 8bit 

    reg                                         i_fval                      ;
    reg                                         i_lval                      ;
    wire                      [   7: 0]         o_data_R   [7:0]            ;
    wire                      [   7: 0]         o_data_G   [7:0]            ;
    wire                      [   7: 0]         o_data_B   [7:0]            ;


    wire                                        o_fval                      ;
    wire                                        o_lval                      ;


    wire                      [  31: 0]         M_AXI_AWADDR                ;
    wire                                        M_AXI_AWVALID               ;
    wire                                        M_AXI_AWREADY               ;
    wire                      [   2: 0]         M_AXI_AWPROT                ;
    wire                      [   1: 0]         M_AXI_AWLOCK                ;
    wire                      [   3: 0]         M_AXI_AWCACHE               ;
    wire                      [   2: 0]         M_AXI_AWSIZE                ;
    wire                      [   1: 0]         M_AXI_AWBURST               ;
    wire                      [   7: 0]         M_AXI_AWLEN                 ;
    wire                      [ 255: 0]         M_AXI_WDATA                 ;
    wire                      [   7: 0]         M_AXI_WSTRB                 ;
    wire                                        M_AXI_WVALID                ;
    wire                                        M_AXI_WREADY                ;
    wire                                        M_AXI_WLAST                 ;
    wire                      [   1: 0]         M_AXI_BRESP                 ;
    wire                                        M_AXI_BVALID                ;
    wire                                        M_AXI_BREADY                ;
    wire                      [  31: 0]         M_AXI_ARADDR                ;
    wire                                        M_AXI_ARVALID               ;
    wire                                        M_AXI_ARREADY               ;
    wire                      [   2: 0]         M_AXI_ARPROT                ;
    wire                      [   1: 0]         M_AXI_ARLOCK                ;
    wire                      [   3: 0]         M_AXI_ARCACHE               ;
    wire                      [   2: 0]         M_AXI_ARSIZE                ;
    wire                      [   1: 0]         M_AXI_ARBURST               ;
    wire                      [   7: 0]         M_AXI_ARLEN                 ;
    wire                      [ 255: 0]         M_AXI_RDATA                 ;
    wire                      [   1: 0]         M_AXI_RRESP                 ;
    wire                                        M_AXI_RVALID                ;
    wire                                        M_AXI_RREADY                ;
    wire                                        M_AXI_RLAST                 ;

    integer                                     file_handle                 ;
    integer                                     read_count                  ;
    integer                                     pixel_x                     ;
    integer                                     pixel_y                     ;
    integer                                     mem_index                   ;
    integer                                     test1_file                  ;
    integer                                     test_a                      ;
    integer                                     frame                       ;
    integer                                     row                         ;
    integer                                     col                         ;

    string                                      img_in_path                 ;
    string                                      img_out_path                ;

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



   reg [7:0] image_mem [0:H_DISP * V_DISP*3 - 1]; // 640x480=307200

    
    reg [7:0] out_mem [0:H_DISP * V_DISP*3 - 1]; // 640x480=307200

    


    reg                                         ref_clk                     ;
    reg                                         sys_clk                     ;

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz 
    end

    initial begin
        ref_clk = 0;
        forever #2.5 ref_clk = ~ref_clk; // 200MHz 
    end

    initial begin
        sys_clk = 0;
        forever #1.25 sys_clk = ~sys_clk; // 400MHz 
    end

    reg                                         sys_rst                     ;

    initial begin
        sys_rst = 1;
        # 20_000
        sys_rst = 0;
    end

    initial begin
        $display("Loading image data...");

        if (img_in_path == "") begin
            string tb_dir;
            tb_dir = _dirname(`__FILE__);
            img_in_path = {tb_dir, "/../../script/image_py/out/Bmp_2_rgb888.txt"};
            img_out_path = {tb_dir, "/../../script/image_py/out/rgb888_output.txt"};
            void'($value$plusargs("IMG_IN=%s", img_in_path));
            void'($value$plusargs("IMG_OUT=%s", img_out_path));
        end
        $readmemh(img_in_path, image_mem);
        $display("Image loading complete");
    
        rst = 1;
        i_data_R[0] = 8'b0;
        i_data_R[1] = 8'b0;
        i_data_R[2] = 8'b0;
        i_data_R[3] = 8'b0;
        i_data_R[4] = 8'b0;
        i_data_R[5] = 8'b0;
        i_data_R[6] = 8'b0;
        i_data_R[7] = 8'b0;

        i_data_G[0] = 8'b0;
        i_data_G[1] = 8'b0;
        i_data_G[2] = 8'b0;
        i_data_G[3] = 8'b0;
        i_data_G[4] = 8'b0;
        i_data_G[5] = 8'b0;
        i_data_G[6] = 8'b0;
        i_data_G[7] = 8'b0;

        i_data_B[0] = 8'b0;
        i_data_B[1] = 8'b0;
        i_data_B[2] = 8'b0;
        i_data_B[3] = 8'b0;
        i_data_B[4] = 8'b0;
        i_data_B[5] = 8'b0;
        i_data_B[6] = 8'b0;
        i_data_B[7] = 8'b0;


        i_fval = 0;
        i_lval = 0;

        #2000;
        rst = 0;
        
        wait (init_calib_complete);  

    for (frame = 0; frame < 2; frame = frame + 1) begin
        i_fval = 1;

        for (row = 0; row < CMOS_V_PIXEL; row = row + 1) begin

            for (col = 0; col < (CMOS_H_PIXEL * 3); col = col + 24) begin

                if (col > ((CMOS_H_PIXEL - H_DISP) - 1) && col < (H_DISP + CMOS_H_PIXEL) && 
                    row > ((CMOS_V_PIXEL - V_DISP)/2 - 1) && row < (V_DISP + CMOS_V_PIXEL)/2) begin
                    
                    pixel_x     =  col - ((CMOS_H_PIXEL - H_DISP))  ;
                    pixel_y     =  row - ((CMOS_V_PIXEL - V_DISP)/2);
                    mem_index   =  (pixel_y * H_DISP * 3) + pixel_x ;
                    i_lval      =  1                                ;        
            
                    i_data_R[0] =  image_mem[mem_index + 3*0 + 0]   ;
                    i_data_R[1] =  image_mem[mem_index + 3*1 + 0]   ;
                    i_data_R[2] =  image_mem[mem_index + 3*2 + 0]   ;
                    i_data_R[3] =  image_mem[mem_index + 3*3 + 0]   ;
                    i_data_R[4] =  image_mem[mem_index + 3*4 + 0]   ;
                    i_data_R[5] =  image_mem[mem_index + 3*5 + 0]   ;
                    i_data_R[6] =  image_mem[mem_index + 3*6 + 0]   ;
                    i_data_R[7] =  image_mem[mem_index + 3*7 + 0]   ;

                    i_data_G[0] =  image_mem[mem_index + 3*0 + 1]   ;
                    i_data_G[1] =  image_mem[mem_index + 3*1 + 1]   ;
                    i_data_G[2] =  image_mem[mem_index + 3*2 + 1]   ;
                    i_data_G[3] =  image_mem[mem_index + 3*3 + 1]   ;
                    i_data_G[4] =  image_mem[mem_index + 3*4 + 1]   ;
                    i_data_G[5] =  image_mem[mem_index + 3*5 + 1]   ;
                    i_data_G[6] =  image_mem[mem_index + 3*6 + 1]   ;
                    i_data_G[7] =  image_mem[mem_index + 3*7 + 1]   ;

                    i_data_B[0] =  image_mem[mem_index + 3*0 + 2]   ;
                    i_data_B[1] =  image_mem[mem_index + 3*1 + 2]   ;
                    i_data_B[2] =  image_mem[mem_index + 3*2 + 2]   ;
                    i_data_B[3] =  image_mem[mem_index + 3*3 + 2]   ;
                    i_data_B[4] =  image_mem[mem_index + 3*4 + 2]   ;
                    i_data_B[5] =  image_mem[mem_index + 3*5 + 2]   ;
                    i_data_B[6] =  image_mem[mem_index + 3*6 + 2]   ;
                    i_data_B[7] =  image_mem[mem_index + 3*7 + 2]   ;

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

    integer     file;     

    initial begin
       
        if (img_out_path == "") begin
            string tb_dir;
            tb_dir = _dirname(`__FILE__);
            img_in_path = {tb_dir, "/../../script/image_py/out/Bmp_2_rgb888.txt"};
            img_out_path = {tb_dir, "/../../script/image_py/out/rgb888_output.txt"};
            void'($value$plusargs("IMG_IN=%s", img_in_path));
            void'($value$plusargs("IMG_OUT=%s", img_out_path));
        end
        file = $fopen(img_out_path, "w");
        if (!file) begin
            $display("Error opening file!");
            $finish;
        end

    end

    reg [31:0] out_counter;

    always @(posedge clk) begin
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


    integer a;

    always @(posedge clk ) begin
        if (u_DDD_Noise_8CH.u_U6_Algorithm_Subsys.o_d_val) begin
            out_mem[out_counter + 3*0  ] <= o_data_R[0];
            out_mem[out_counter + 3*1  ] <= o_data_R[1];
            out_mem[out_counter + 3*2  ] <= o_data_R[2];
            out_mem[out_counter + 3*3  ] <= o_data_R[3];
            out_mem[out_counter + 3*4  ] <= o_data_R[4];
            out_mem[out_counter + 3*5  ] <= o_data_R[5];
            out_mem[out_counter + 3*6  ] <= o_data_R[6];
            out_mem[out_counter + 3*7  ] <= o_data_R[7];

            out_mem[out_counter + 3*0+1] <= o_data_G[0];
            out_mem[out_counter + 3*1+1] <= o_data_G[1];
            out_mem[out_counter + 3*2+1] <= o_data_G[2];
            out_mem[out_counter + 3*3+1] <= o_data_G[3];
            out_mem[out_counter + 3*4+1] <= o_data_G[4];
            out_mem[out_counter + 3*5+1] <= o_data_G[5];
            out_mem[out_counter + 3*6+1] <= o_data_G[6];
            out_mem[out_counter + 3*7+1] <= o_data_G[7];

            out_mem[out_counter + 3*0+2] <= o_data_B[0];
            out_mem[out_counter + 3*1+2] <= o_data_B[1];
            out_mem[out_counter + 3*2+2] <= o_data_B[2];
            out_mem[out_counter + 3*3+2] <= o_data_B[3];
            out_mem[out_counter + 3*4+2] <= o_data_B[4];
            out_mem[out_counter + 3*5+2] <= o_data_B[5];
            out_mem[out_counter + 3*6+2] <= o_data_B[6];
            out_mem[out_counter + 3*7+2] <= o_data_B[7];

        end
    end

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

    DDD_Noise_8CH#(
        .DDR_BASE_ADDR                             (0                          ),
        .WAIT                                      (0                          ),
        .CMOS_H_PIXEL                              (CMOS_H_PIXEL               ),
        .CMOS_V_PIXEL                              (CMOS_V_PIXEL               ),
        .H_DISP                                    (H_DISP                     ),
        .V_DISP                                    (V_DISP                     ),
        .MACROBLOCK_THREASHOLD                     (32                         ) 
    )
    u_DDD_Noise_8CH(
    //////////////////////////////////////////
    //System
    //////////////////////////////////////////
        .clk                                       (clk                        ),
        .ui_clk                                    (ui_clk                     ),
        .rst_n                                     (~(rst)                     ),
        .ui_clk_sync_rst                           (ui_clk_sync_rst            ),
    //////////////////////////////////////////
    //Data_in
    //////////////////////////////////////////
        .i_data_R                                  (i_data_R                   ),// 閺夊牊鎸搁崣鍡涘极閻楀牆绁�
        .i_data_G                                  (i_data_G                   ),// 閺夊牊鎸搁崣鍡涘极閻楀牆绁�
        .i_data_B                                  (i_data_B                   ),// 閺夊牊鎸搁崣鍡涘极閻楀牆绁�
        .i_fval                                    (i_fval                     ),// 閺夊牊鎸搁崣鍡涙儍閸戞烤P閻㈩垎鍕畳闁跨噦鎷�???
        .i_lval                                    (i_lval                     ),// 閺夊牊鎸搁崣鍡涙儍閸戞烤P閻炴稑鏈﹢渚€鏁撻敓锟�???
    //////////////////////////////////////////
    //Data_out:TFT_LCD
    //////////////////////////////////////////
        .o_fval                                    (o_fval                     ),// 閺夊牊鎸搁崵鐠橤A閻㈩垎鍕畳闁跨噦鎷�???
        .o_lval                                    (o_lval                     ),// 閺夊牊鎸搁崵鐠橤A閻炴稑鏈﹢渚€鏁撻敓锟�???
        .o_data_R                                  (o_data_R                   ),// 闁告艾楠搁ˇ鈺呮偠閸℃ɑ娈堕柟鍦敯 8bit
        .o_data_G                                  (o_data_G                   ),// 闁告艾楠搁ˇ鈺呮偠閸℃ɑ娈堕柟鍦懟 8bit
        .o_data_B                                  (o_data_B                   ),// 闁告艾楠搁ˇ鈺呮偠閸℃ɑ娈堕柟鍦懗 8bit
    //////////////////////////////////////////
    //DDR_Inteface
    //////////////////////////////////////////
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

    reg                                         aresetn                     ;

    always @(posedge ui_clk) begin
        aresetn				<= ~ui_clk_sync_rst;
    end
    

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


    ddr3_model u_ddr3_model0(
    .rst_n                                     (ddr3_reset_n              ),

    .ck                                        (ddr3_ck_p                  ),
    
    .ck_n                                      (ddr3_ck_n                  ),
    
    .cke                                       (ddr3_cke                   ),
    
    .cs_n                                      (ddr3_cs_n                  ),
    
    .ras_n                                     (ddr3_ras_n                 ),
    
    .cas_n                                     (ddr3_cas_n                 ),
    
    .we_n                                      (ddr3_we_n                  ),
    
    .dm_tdqs                                   (ddr3_dm[1:0]                    ),
    
    .ba                                        (ddr3_ba                    ),
    
    .addr                                      (ddr3_addr                  ),
    
    .dq                                        (ddr3_dq[15:0]              ),
    
    .dqs                                       (ddr3_dqs_p[1:0]           ),
    
    .dqs_n                                     (ddr3_dqs_n[1:0]           ),
    
    .tdqs_n                                    (                           ),
    
    .odt                                       (ddr3_odt                   ) 
    );
        
    ddr3_model u_ddr3_model1(
    .rst_n                                     (ddr3_reset_n               ),

    .ck                                        (ddr3_ck_p                  ),
    
    .ck_n                                      (ddr3_ck_n                  ),
    
    .cke                                       (ddr3_cke                   ),
    
    .cs_n                                      (ddr3_cs_n                  ),
    
    .ras_n                                     (ddr3_ras_n                 ),
    
    .cas_n                                     (ddr3_cas_n                 ),
    
    .we_n                                      (ddr3_we_n                  ),
    
    .dm_tdqs                                   (ddr3_dm[3:2]                    ),
    
    .ba                                        (ddr3_ba                    ),
    
    .addr                                      (ddr3_addr                  ),
    
    .dq                                        (ddr3_dq[31:16]             ),
    
    .dqs                                       (ddr3_dqs_p[3:2]            ),
    
    .dqs_n                                     (ddr3_dqs_n[3:2]            ),
    
    .tdqs_n                                    (                           ),
    
    .odt                                       (ddr3_odt                   ) 
    );


endmodule
