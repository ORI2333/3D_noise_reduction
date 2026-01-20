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
// Last modified Date:     2025/03/14 09:10:23 
// Last Version:           V1.0 
// Descriptions:            
//---------------------------------------------------------------------------------------- 
// Created by:             USER_NAME
// Created date:           2025/03/14 09:10:23 
// Version:                V1.0 
// TEXT NAME:              Mul_Channel_DDR.v 
// PATH:                   D:\EDA_Work_Space\FPGA_Worker\3DNR\3DNR.srcs\sources_1\3D_Denoise\Mul_Channel_DDR.v 
// Descriptions:            
//                          
//---------------------------------------------------------------------------------------- 
//****************************************************************************************// 

module U1_Mul_Channel_DDR(
    
    input                                       clk                         ,
    input                                       ui_clk                      ,
    input                                       rst                         ,
    input                                       ui_clk_sync_rst             ,
//---------------------------------------------------------------------------------------
// WR                                                                                    
//---------------------------------------------------------------------------------------

    input                                       M_wr_req        [2:0]       ,//!本地写请�?
    output wire                                 M_wr_granted    [2:0]       ,//!可接收一轮传�?
    output wire                                 M_wr_busy       [2:0]       ,
    input                     [  31: 0]         M_wr_len        [2:0]       ,//!写长度：单位打拍数量
    input                     [  31: 0]         M_wr_addr       [2:0]       ,//!写地�?
    input                     [  63: 0]         M_wr_din        [2:0]       ,//!写数据输�?
    input                                       M_wr_dval       [2:0]       ,//!写数据有�?
    input                                       M_wr_finish     [2:0]       ,//!写完�?


//---------------------------------------------------------------------------------------
// RD                                                                             
//---------------------------------------------------------------------------------------


    input                                       M_rd_req        [2:0]       ,//!本地读请�?
    output wire                                 M_rd_granted    [2:0]       ,//!可接收一轮传�?
    output wire                                 M_rd_busy       [2:0]       ,
    input                     [  31: 0]         M_rd_addr       [2:0]       ,//!读地�?
    input                     [  31: 0]         M_rd_lenth      [2:0]       ,//!读长度：单位字节
    output                    [  63: 0]         M_rd_dout       [2:0]       ,//!读数据输�?
    output wire                                 M_rd_dval       [2:0]       ,//!读数据有�?
    output wire                                 M_rd_finish     [2:0]       , //!读事务完�?

    //////////////////////////////////////////
    //DDR_Inteface
    //////////////////////////////////////////
  // Master Write Address
    output wire               [   5: 0]         M_AXI_AWID                  ,
    output wire               [  31: 0]         M_AXI_AWADDR                ,
    output wire               [   7: 0]         M_AXI_AWLEN                 ,
    output wire               [   2: 0]         M_AXI_AWSIZE                ,
    output wire               [   1: 0]         M_AXI_AWBURST               ,
    output wire                                 M_AXI_AWLOCK                ,
    output wire               [   3: 0]         M_AXI_AWCACHE               ,
    output wire               [   2: 0]         M_AXI_AWPROT                ,
    output wire               [   3: 0]         M_AXI_AWQOS                 ,
    output wire               [   1: 0]         M_AXI_AWUSER                ,
    output wire                                 M_AXI_AWVALID               ,
    input                                       M_AXI_AWREADY               ,
  // Master Write Data
    output wire               [ 255: 0]         M_AXI_WDATA                 ,
    output wire               [   7: 0]         M_AXI_WSTRB                 ,

    output wire                                 M_AXI_WLAST                 ,
    output wire               [   0: 0]         M_AXI_WUSER                 ,
    output wire                                 M_AXI_WVALID                ,
    input                                       M_AXI_WREADY                ,

  // Master Write Response
    input                     [   0: 0]         M_AXI_BID                   ,
    input                     [   1: 0]         M_AXI_BRESP                 ,
    input                     [   0: 0]         M_AXI_BUSER                 ,
    input                                       M_AXI_BVALID                ,
    output wire                                 M_AXI_BREADY                ,
    // Master Read Address
    output wire               [   5: 0]         M_AXI_ARID                  ,
    output wire               [  31: 0]         M_AXI_ARADDR                ,
    output wire               [   7: 0]         M_AXI_ARLEN                 ,
    output wire               [   2: 0]         M_AXI_ARSIZE                ,
    output wire               [   1: 0]         M_AXI_ARBURST               ,
    output wire                                 M_AXI_ARLOCK                ,
    output wire               [   3: 0]         M_AXI_ARCACHE               ,
    output wire               [   2: 0]         M_AXI_ARPROT                ,
    output wire               [   3: 0]         M_AXI_ARQOS                 ,
    output wire               [   1: 0]         M_AXI_ARUSER                ,
    output wire                                 M_AXI_ARVALID               ,
    input                                       M_AXI_ARREADY               ,
  // Master Read Data
    input                     [   3: 0]         M_AXI_RID                   ,
    input                     [ 255: 0]         M_AXI_RDATA                 ,
    input                     [   1: 0]         M_AXI_RRESP                 ,
    input                                       M_AXI_RLAST                 ,
    input                     [   0: 0]         M_AXI_RUSER                 ,
    input                                       M_AXI_RVALID                ,
    input                                       M_AXI_RREADY                 

    );


U1_0_Mul_Channel_DDR_Wr_channel u_U1_0_Mul_Channel_DDR_Wr_channel(
    .clk                                       (clk                        ),
    .ui_clk                                    (ui_clk                     ),
    .rst                                       (rst                        ),
    .ui_clk_sync_rst                           (ui_clk_sync_rst            ),

    .M_wr_req                                  (M_wr_req                   ),// !本地写请�?
    .M_wr_granted                              (M_wr_granted               ),// !可接收一轮传�?
    .M_wr_busy                                 (M_wr_busy                  ),
    .M_wr_len                                  (M_wr_len                   ),// !写长度：单位打拍数量
    .M_wr_addr                                 (M_wr_addr                  ),// !写地�?
    .M_wr_din                                  (M_wr_din                   ),// !写数据输�?
    .M_wr_dval                                 (M_wr_dval                  ),// !写数据有�?
    .M_wr_finish                               (M_wr_finish                ),// !写完�?
//---------------------------------------------------------------------------
// output AXI4_WR
//---------------------------------------------------------------------------
// Master Write Address
    .M_AXI_AWID                                (M_AXI_AWID                 ),
    .M_AXI_AWADDR                              (M_AXI_AWADDR               ),
    .M_AXI_AWLEN                               (M_AXI_AWLEN                ),
    .M_AXI_AWSIZE                              (M_AXI_AWSIZE               ),
    .M_AXI_AWBURST                             (M_AXI_AWBURST              ),
    .M_AXI_AWLOCK                              (M_AXI_AWLOCK               ),
    .M_AXI_AWCACHE                             (M_AXI_AWCACHE              ),
    .M_AXI_AWPROT                              (M_AXI_AWPROT               ),
    .M_AXI_AWQOS                               (M_AXI_AWQOS                ),
    .M_AXI_AWUSER                              (M_AXI_AWUSER               ),
    .M_AXI_AWVALID                             (M_AXI_AWVALID              ),
    .M_AXI_AWREADY                             (M_AXI_AWREADY              ),
// Master Write Data
    .M_AXI_WDATA                               (M_AXI_WDATA                ),
    .M_AXI_WSTRB                               (M_AXI_WSTRB                ),
    .M_AXI_WLAST                               (M_AXI_WLAST                ),
    .M_AXI_WUSER                               (M_AXI_WUSER                ),
    .M_AXI_WVALID                              (M_AXI_WVALID               ),
    .M_AXI_WREADY                              (M_AXI_WREADY               ),
// Master Write Response
    .M_AXI_BID                                 (M_AXI_BID                  ),
    .M_AXI_BRESP                               (M_AXI_BRESP                ),
    .M_AXI_BUSER                               (M_AXI_BUSER                ),
    .M_AXI_BVALID                              (M_AXI_BVALID               ),
    .M_AXI_BREADY                              (M_AXI_BREADY               ) 
);

//---------------------------------------------------------------------------------------
// RD                                                                                    
//---------------------------------------------------------------------------------------

U1_0_Mul_Channel_DDR_Rd_channel u_U1_0_Mul_Channel_DDR_Rd_channel(
    .clk                                       (clk                        ),
    .ui_clk                                    (ui_clk                     ),
    .rst                                       (rst                        ),
    .ui_clk_sync_rst                           (ui_clk_sync_rst            ),

    .M_rd_req                                  (M_rd_req                   ),// !本地写请�?
    .M_rd_granted                              (M_rd_granted               ),// !可接收一轮传�?
    .M_rd_busy                                 (M_rd_busy                  ),// !
    .M_rd_len                                  (M_rd_lenth                   ),// !写长度：单位打拍数量
    .M_rd_addr                                 (M_rd_addr                  ),// !写地�?
    .M_rd_dout                                 (M_rd_dout                  ),// !写数据输�?
    .M_rd_dval                                 (M_rd_dval                  ),// !写数据有�?
    .M_rd_finish                               (M_rd_finish                ),// !写完�?
//---------------------------------------------------------------------------
// output AXI4_WR
//---------------------------------------------------------------------------
// Master Write Address
    .M_AXI_ARID                                (M_AXI_ARID                 ),
    .M_AXI_ARADDR                              (M_AXI_ARADDR               ),
    .M_AXI_ARLEN                               (M_AXI_ARLEN                ),
    .M_AXI_ARSIZE                              (M_AXI_ARSIZE               ),
    .M_AXI_ARBURST                             (M_AXI_ARBURST              ),
    .M_AXI_ARLOCK                              (M_AXI_ARLOCK               ),
    .M_AXI_ARCACHE                             (M_AXI_ARCACHE              ),
    .M_AXI_ARPROT                              (M_AXI_ARPROT               ),
    .M_AXI_ARQOS                               (M_AXI_ARQOS                ),
    .M_AXI_ARUSER                              (M_AXI_ARUSER               ),
    .M_AXI_ARVALID                             (M_AXI_ARVALID              ),
    .M_AXI_ARREADY                             (M_AXI_ARREADY              ),
// Master Write Data
    .M_AXI_RID                                 (M_AXI_RID                  ),
    .M_AXI_RDATA                               (M_AXI_RDATA                ),
    .M_AXI_RRESP                               (M_AXI_RRESP                ),
    .M_AXI_RLAST                               (M_AXI_RLAST                ),
    .M_AXI_RUSER                               (M_AXI_RUSER                ),
    .M_AXI_RVALID                              (M_AXI_RVALID               ),
    .M_AXI_RREADY                              (M_AXI_RREADY               ) 
);





endmodule
