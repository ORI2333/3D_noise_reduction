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

module U5_3_BRAM_28port#(
    parameter                 ADDR_WIDTH                  = 8     ,
    parameter                 DATA_WIDTH                  = 8     ,
    parameter                 DEPTH                       = 256   
)(
    input                                               clk       ,
    input                                               rst       ,
    input                                               we1       ,
    input                                               we2       ,

    input                     [ADDR_WIDTH-1: 0]         wr_addr1  ,
    input                     [ADDR_WIDTH-1: 0]         wr_addr2  ,

    input                     [DATA_WIDTH-1: 0]         wr_data1  ,
    input                     [DATA_WIDTH-1: 0]         wr_data2  ,


    input                                               re1       ,
    input                                               re2       ,
    input                                               re3       ,
    input                                               re4       ,
    input                                               re5       ,
    input                                               re6       ,
    input                                               re7       ,
    input                                               re8       ,

    input                     [ADDR_WIDTH-1: 0]         rd_addr1  ,
    input                     [ADDR_WIDTH-1: 0]         rd_addr2  ,
    input                     [ADDR_WIDTH-1: 0]         rd_addr3  ,
    input                     [ADDR_WIDTH-1: 0]         rd_addr4  ,
    input                     [ADDR_WIDTH-1: 0]         rd_addr5  ,
    input                     [ADDR_WIDTH-1: 0]         rd_addr6  ,
    input                     [ADDR_WIDTH-1: 0]         rd_addr7  ,
    input                     [ADDR_WIDTH-1: 0]         rd_addr8  ,

    output reg                [DATA_WIDTH-1: 0]         rd_data1  ,
    output reg                [DATA_WIDTH-1: 0]         rd_data2  ,
    output reg                [DATA_WIDTH-1: 0]         rd_data3  ,
    output reg                [DATA_WIDTH-1: 0]         rd_data4  ,
    output reg                [DATA_WIDTH-1: 0]         rd_data5  ,
    output reg                [DATA_WIDTH-1: 0]         rd_data6  ,
    output reg                [DATA_WIDTH-1: 0]         rd_data7  ,
    output reg                [DATA_WIDTH-1: 0]         rd_data8            
);


    localparam integer BANK_DEPTH = (DEPTH + 1) / 2;
    localparam integer BANK_DEPTH_ROUNDED = (1 << $clog2(BANK_DEPTH));
    localparam integer BANK_ADDR_WIDTH = $clog2(BANK_DEPTH_ROUNDED);

    wire [7:0] re = {re8, re7, re6, re5, re4, re3, re2, re1};

    wire [ADDR_WIDTH-1:0] rd_addr [7:0];
    assign rd_addr[0] = rd_addr1;
    assign rd_addr[1] = rd_addr2;
    assign rd_addr[2] = rd_addr3;
    assign rd_addr[3] = rd_addr4;
    assign rd_addr[4] = rd_addr5;
    assign rd_addr[5] = rd_addr6;
    assign rd_addr[6] = rd_addr7;
    assign rd_addr[7] = rd_addr8;

    wire wr1_bank = wr_addr1[0];
    wire wr2_bank = wr_addr2[0];
    wire [BANK_ADDR_WIDTH-1:0] wr1_index = wr_addr1[ADDR_WIDTH-1:1];
    wire [BANK_ADDR_WIDTH-1:0] wr2_index = wr_addr2[ADDR_WIDTH-1:1];

    wire we_even = (we1 & ~wr1_bank) | (we2 & ~wr2_bank);
    wire we_odd  = (we1 &  wr1_bank) | (we2 &  wr2_bank);

    wire [BANK_ADDR_WIDTH-1:0] wr_even_index =
        (we2 & ~wr2_bank) ? wr2_index : wr1_index;
    wire [BANK_ADDR_WIDTH-1:0] wr_odd_index =
        (we2 &  wr2_bank) ? wr2_index : wr1_index;

    wire [DATA_WIDTH-1:0] wr_even_data =
        (we2 & ~wr2_bank) ? wr_data2 : wr_data1;
    wire [DATA_WIDTH-1:0] wr_odd_data =
        (we2 &  wr2_bank) ? wr_data2 : wr_data1;

    wire [DATA_WIDTH-1:0] dout_even [7:0];
    wire [DATA_WIDTH-1:0] dout_odd  [7:0];

    reg  [7:0]             rd_bank_d;
    reg  [7:0]             rd_en_d;

    integer k;
    always @(posedge clk) begin
        if (rst) begin
            rd_bank_d <= '0;
            rd_en_d   <= '0;
        end else begin
            for (k = 0; k < 8; k = k + 1) begin
                rd_bank_d[k] <= rd_addr[k][0];
                rd_en_d[k]   <= re[k];
            end
        end
    end

    genvar p;
    generate
        for (p = 0; p < 8; p = p + 1) begin : gen_rd
            wire en_even_p = re[p] & ~rd_addr[p][0];
            wire en_odd_p  = re[p] &  rd_addr[p][0];
            wire [BANK_ADDR_WIDTH-1:0] rd_index_p = rd_addr[p][ADDR_WIDTH-1:1];

            xpm_memory_sdpram #(
                .ADDR_WIDTH_A            (BANK_ADDR_WIDTH            ),
                .ADDR_WIDTH_B            (BANK_ADDR_WIDTH            ),
                .AUTO_SLEEP_TIME         (0                          ),
                .BYTE_WRITE_WIDTH_A      (DATA_WIDTH                 ),
                .CASCADE_HEIGHT          (0                          ),
                .CLOCKING_MODE           ("common_clock"             ),
                .ECC_MODE                ("no_ecc"                   ),
                .MEMORY_INIT_FILE        ("none"                     ),
                .MEMORY_INIT_PARAM       (""                         ),
                .MEMORY_OPTIMIZATION     ("true"                     ),
                .MEMORY_PRIMITIVE        ("block"                    ),
                .MEMORY_SIZE             (DATA_WIDTH * BANK_DEPTH_ROUNDED),
                .MESSAGE_CONTROL         (0                          ),
                .READ_DATA_WIDTH_B       (DATA_WIDTH                 ),
                .READ_LATENCY_B          (1                          ),
                .READ_RESET_VALUE_B      ("0"                        ),
                .RST_MODE_A              ("SYNC"                     ),
                .RST_MODE_B              ("SYNC"                     ),
                .SIM_ASSERT_CHK          (0                          ),
                .USE_EMBEDDED_CONSTRAINT (0                          ),
                .USE_MEM_INIT            (0                          ),
                .WAKEUP_TIME             ("disable_sleep"            ),
                .WRITE_DATA_WIDTH_A      (DATA_WIDTH                 ),
                .WRITE_MODE_B            ("read_first"               )
            ) u_xpm_even (
                .clka                    (clk                        ),
                .ena                     (1'b1                       ),
                .wea                     (we_even                    ),
                .addra                   (wr_even_index[BANK_ADDR_WIDTH-1:0]),
                .dina                    (wr_even_data               ),
                .injectsbiterra          (1'b0                       ),
                .injectdbiterra          (1'b0                       ),

                .clkb                    (clk                        ),
                .enb                     (en_even_p                  ),
                .addrb                   (rd_index_p[BANK_ADDR_WIDTH-1:0]),
                .doutb                   (dout_even[p]              ),
                .rstb                    (rst                        ),
                .regceb                  (1'b1                       ),
                .sleep                   (1'b0                       )
            );

            xpm_memory_sdpram #(
                .ADDR_WIDTH_A            (BANK_ADDR_WIDTH            ),
                .ADDR_WIDTH_B            (BANK_ADDR_WIDTH            ),
                .AUTO_SLEEP_TIME         (0                          ),
                .BYTE_WRITE_WIDTH_A      (DATA_WIDTH                 ),
                .CASCADE_HEIGHT          (0                          ),
                .CLOCKING_MODE           ("common_clock"             ),
                .ECC_MODE                ("no_ecc"                   ),
                .MEMORY_INIT_FILE        ("none"                     ),
                .MEMORY_INIT_PARAM       (""                         ),
                .MEMORY_OPTIMIZATION     ("true"                     ),
                .MEMORY_PRIMITIVE        ("block"                    ),
                .MEMORY_SIZE             (DATA_WIDTH * BANK_DEPTH_ROUNDED),
                .MESSAGE_CONTROL         (0                          ),
                .READ_DATA_WIDTH_B       (DATA_WIDTH                 ),
                .READ_LATENCY_B          (1                          ),
                .READ_RESET_VALUE_B      ("0"                        ),
                .RST_MODE_A              ("SYNC"                     ),
                .RST_MODE_B              ("SYNC"                     ),
                .SIM_ASSERT_CHK          (0                          ),
                .USE_EMBEDDED_CONSTRAINT (0                          ),
                .USE_MEM_INIT            (0                          ),
                .WAKEUP_TIME             ("disable_sleep"            ),
                .WRITE_DATA_WIDTH_A      (DATA_WIDTH                 ),
                .WRITE_MODE_B            ("read_first"               )
            ) u_xpm_odd (
                .clka                    (clk                        ),
                .ena                     (1'b1                       ),
                .wea                     (we_odd                     ),
                .addra                   (wr_odd_index[BANK_ADDR_WIDTH-1:0]),
                .dina                    (wr_odd_data                ),
                .injectsbiterra          (1'b0                       ),
                .injectdbiterra          (1'b0                       ),

                .clkb                    (clk                        ),
                .enb                     (en_odd_p                   ),
                .addrb                   (rd_index_p[BANK_ADDR_WIDTH-1:0]),
                .doutb                   (dout_odd[p]               ),
                .rstb                    (rst                        ),
                .regceb                  (1'b1                       ),
                .sleep                   (1'b0                       )
            );
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            rd_data1 <= '0;
            rd_data2 <= '0;
            rd_data3 <= '0;
            rd_data4 <= '0;
            rd_data5 <= '0;
            rd_data6 <= '0;
            rd_data7 <= '0;
            rd_data8 <= '0;
        end else begin
            if (rd_en_d[0]) rd_data1 <= rd_bank_d[0] ? dout_odd[0]  : dout_even[0];
            if (rd_en_d[1]) rd_data2 <= rd_bank_d[1] ? dout_odd[1]  : dout_even[1];
            if (rd_en_d[2]) rd_data3 <= rd_bank_d[2] ? dout_odd[2]  : dout_even[2];
            if (rd_en_d[3]) rd_data4 <= rd_bank_d[3] ? dout_odd[3]  : dout_even[3];
            if (rd_en_d[4]) rd_data5 <= rd_bank_d[4] ? dout_odd[4]  : dout_even[4];
            if (rd_en_d[5]) rd_data6 <= rd_bank_d[5] ? dout_odd[5]  : dout_even[5];
            if (rd_en_d[6]) rd_data7 <= rd_bank_d[6] ? dout_odd[6]  : dout_even[6];
            if (rd_en_d[7]) rd_data8 <= rd_bank_d[7] ? dout_odd[7]  : dout_even[7];
        end
    end

    

endmodule                                                          
