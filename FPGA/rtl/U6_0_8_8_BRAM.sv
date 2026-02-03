`timescale 1ns / 1ps 
//****************************************VSCODE PLUG-IN**********************************// 
//---------------------------------------------------------------------------------------- 
// IDE :                   VSCODE      
// VSCODE plug-in version: Verilog-Hdl-Format-2.4.20240526
// VSCODE plug-in author : Jiang Percy 
//---------------------------------------------------------------------------------------- 
//****************************************Copyright (c)***********************************// 
// Copyright(C)            COMPANY_NAME
// All rights reserved      
// File name:               
// Last modified Date:     2025/03/18 11:16:56 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/18 11:16:56 
// Version:                V1.0 
// TEXT NAME:              U5_3_BRAM_28port.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\U5_3_BRAM_28port.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U6_0_8_8_BRAM#(
    parameter                 ADDR_WIDTH                  = 8     ,
    parameter                 DATA_WIDTH                  = 8     ,
    parameter                 DEPTH                       = 256   ,
    parameter                 CHANNEL                     = 8     
)(
    input                                    clk                  ,
    input                                    rst                  ,

    input                                    we      [CHANNEL-1:0],

    input                  [ADDR_WIDTH-1: 0] wr_addr [CHANNEL-1:0],

    input                  [DATA_WIDTH-1: 0] wr_data [CHANNEL-1:0],

    input                                    re      [CHANNEL-1:0],

    input                  [ADDR_WIDTH-1: 0] rd_addr [CHANNEL-1:0],

    output reg             [DATA_WIDTH-1: 0] rd_data [CHANNEL-1:0]
);

    localparam integer DEPTH_ROUNDED = (1 << $clog2(DEPTH));
    localparam integer ADDR_AW       = $clog2(DEPTH_ROUNDED);

    genvar i;

    generate
        for (i = 0; i < CHANNEL; i = i + 1) begin
            wire [DATA_WIDTH-1:0] doutb;

            xpm_memory_sdpram #(
                .ADDR_WIDTH_A           (ADDR_AW                    ),
                .ADDR_WIDTH_B           (ADDR_AW                    ),
                .AUTO_SLEEP_TIME        (0                          ),
                .BYTE_WRITE_WIDTH_A     (DATA_WIDTH                 ),
                .CASCADE_HEIGHT         (0                          ),
                .CLOCKING_MODE          ("common_clock"             ),
                .ECC_MODE               ("no_ecc"                   ),
                .MEMORY_INIT_FILE       ("none"                     ),
                .MEMORY_INIT_PARAM      (""                         ),
                .MEMORY_OPTIMIZATION    ("true"                     ),
                .MEMORY_PRIMITIVE       ("block"                    ),
                .MEMORY_SIZE            (DATA_WIDTH * DEPTH_ROUNDED ),
                .MESSAGE_CONTROL        (0                          ),
                .READ_DATA_WIDTH_B      (DATA_WIDTH                 ),
                .READ_LATENCY_B         (1                          ),
                .READ_RESET_VALUE_B     ("0"                        ),
                .RST_MODE_A             ("SYNC"                     ),
                .RST_MODE_B             ("SYNC"                     ),
                .SIM_ASSERT_CHK         (0                          ),
                .USE_EMBEDDED_CONSTRAINT(0                          ),
                .USE_MEM_INIT           (0                          ),
                .WAKEUP_TIME            ("disable_sleep"            ),
                .WRITE_DATA_WIDTH_A     (DATA_WIDTH                 ),
                .WRITE_MODE_B           ("read_first"               )
            ) u_xpm_memory_sdpram (
                .clka                   (clk                        ),
                .ena                    (1'b1                       ),
                .wea                    (we[i]                      ),
                .addra                  (wr_addr[i][ADDR_AW-1:0]     ),
                .dina                   (wr_data[i]                 ),
                .injectsbiterra         (1'b0                       ),
                .injectdbiterra         (1'b0                       ),

                .clkb                   (clk                        ),
                .enb                    (re[i]                      ),
                .addrb                  (rd_addr[i][ADDR_AW-1:0]     ),
                .doutb                  (doutb                      ),
                .rstb                   (rst                        ),
                .regceb                 (1'b1                       ),
                .sleep                  (1'b0                       )
            );

            always @(posedge clk) begin
                if (rst) begin
                    rd_data[i] <= '0;
                end else if (re[i]) begin
                    rd_data[i] <= doutb;
                end
            end
        end
    endgenerate

endmodule                                                          
