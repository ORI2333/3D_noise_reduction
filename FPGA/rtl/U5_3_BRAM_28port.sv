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


    //(*ram_style="block"*) 

    reg [DATA_WIDTH-1:0] bram [0:DEPTH-1];  

    always @(posedge clk ) 
    begin
        if (we1) begin
            bram[wr_addr1] <= wr_data1;
        end
    end

    always @(posedge clk ) 
    begin
        if (we2) begin
            bram[wr_addr2] <= wr_data2;
        end
    end

    //read1
    always @(posedge clk)
    begin
        if(re1)
            rd_data1 <= bram[rd_addr1];
        else
            rd_data1 <= rd_data1;
    end
    //read2
    always @(posedge clk)
    begin
        if(re2)
            rd_data2 <= bram[rd_addr2];
        else
            rd_data2 <= rd_data2;
    end
        //read3
    always @(posedge clk)
    begin
        if(re3)
            rd_data3 <= bram[rd_addr3];
        else
            rd_data3 <= rd_data3;
    end
    //read4
    always @(posedge clk)
    begin
        if(re4)
            rd_data4 <= bram[rd_addr4];
        else
            rd_data4 <= rd_data4;
    end
    //read5
    always @(posedge clk)
    begin
        if(re5)
            rd_data5 <= bram[rd_addr5];
        else
            rd_data5 <= rd_data5;
    end
    //read6
    always @(posedge clk)
    begin
        if(re6)
            rd_data6 <= bram[rd_addr6];
        else
            rd_data6 <= rd_data6;
    end
    //read7
    always @(posedge clk)
    begin
        if(re7)
            rd_data7 <= bram[rd_addr7];
        else
            rd_data7 <= rd_data7;
    end
    //read8
    always @(posedge clk)
    begin
        if(re8)
            rd_data8 <= bram[rd_addr8];
        else
            rd_data8 <= rd_data8;
    end

    

endmodule                                                          
